require 'builder'
require 'nokogiri'
require 'rgl/adjacency'

module Korwe
  module TheCore
    class CoreMessageXmlSerializer

      TIMESTAMP_FORMAT = '%Y%m%dT%H%M%S.%L'

      def initialize(api_definition_path)
        @api_definition = ApiDefinition.new(api_definition_path)
      end

      def serialize(message)
        builder = Builder::XmlMarkup.new(:indent=>2)

        builder.coreMessage do |b|
          b.sessionId(message.session_id)
          b.messageType(message.message_type.to_s)
          b.guid(message.guid)
          b.choreography(message.choreography)
          b.description(message.description)
          b.timeStamp(message.timestamp.utc.strftime(TIMESTAMP_FORMAT))

          case message.message_type
            when :ServiceRequest
              serialize_request_function(b, message)
            when :InitiateSessionResponse, :KillSessionResponse
              add_response_elements(b, message)
            when :ServiceResponse
              add_response_elements(b, message)
              b.hasData(message.data_available)
            when :DataResponse
              add_response_elements(b, message)
              b.data(message.data)
          end
        end
      end

      def deserialize(message_string)
        document = Nokogiri::XML::Document.parse(message_string, nil, 'UTF-8', Nokogiri::XML::ParseOptions::NOBLANKS)
        root = document.child
        return if root.nil? or root.name != 'coreMessage'
        session_id = node_value(root, 'sessionId')
        guid = node_value(root, 'guid')
        message_type = node_value(root, 'messageType')

        return if [session_id, guid, message_type].any? {|v| v.nil? or v.empty?}

        successful = node_value(root, 'successful') == '1' ? true : false

        core_message = nil

        case message_type.to_sym
          when :InitiateSessionResponse
            core_message = InitiateSessionResponse.new(session_id, guid, successful)
            set_response_fields(root, core_message)
          when :KillSessionResponse
            core_message = KillSessionResponse.new(session_id, guid, successful)
            set_response_fields(root, core_message)
          when :ServiceResponse
            has_data = node_value(root, 'hasData') == '1' ? true : false
            core_message = ServiceResponse.new(session_id, guid, successful, has_data)
            set_response_fields(root, core_message)
          when :DataResponse
            data_text = node_value(root, 'data')
            data = data_text.nil? ? nil : deserialize_data(Nokogiri::XML(data_text, nil, 'UTF-8', Nokogiri::XML::ParseOptions::NOBLANKS).child, nil, RGL::DirectedAdjacencyGraph.new, [])
            core_message = DataResponse.new(session_id, guid, data)
            set_response_fields(root, core_message)
        end

        unless core_message.nil?
          core_message.choreography= node_value(root, 'choreography')
          core_message.description= node_value(root, 'description')
          core_message.timestamp= Time.parse(node_value(root, 'timeStamp'))
        end

        core_message
      end

      def add_response_elements(builder, message)
        builder.errorCode(message.error_code)
        builder.errorMessage(message.error_message)
        builder.successful(message.successful ? '1' : '0')
      end

      def set_response_fields(node, core_message)
        core_message.error_code = node_value(node, 'errorCode')
        core_message.error_message = node_value(node, 'errorMessage')
      end

      def node_value(node, css)
        found_node = node.at_css(css)
        found_node.nil? ? nil : found_node.text
      end

      def serialize_request_function(builder, message)
        #TODO: HANDLE FUNCTION ERRORS - i.e when supplying incorrect args for function
        function_definition = @api_definition.services[message.choreography].method_list[message.function]
        builder.function(function_definition.name)
        builder.parameters {
          message.params.each do |param_name,param_value|
            builder.parameter {
              builder.name param_name
              type_builder = Builder::XmlMarkup.new
              builder.value serialize_type(type_builder, nil, function_definition.parameters[param_name], param_value).target!
            }
          end
        }
      end

      def serialize_type(builder, property_definition, type_name, value)
        type = @api_definition.types[type_name]

        tag_name = property_definition.nil? ? type.name : property_definition.name

        if ApiDefinition::PRIMITIVE_TYPES.keys.any?{|k| k==type_name}
          builder.__send__ tag_name, value.to_s
        else
          if ['list', 'set'].any? {|k| k==type.name}
            builder.tag!(tag_name) {
              unless property_definition.nil?
                value.each do |o|
                  serialize_type builder, nil, property_definition.type_parameters.first, o
                end
              else
                #TODO: Handle non property lists - and lists without generic parameter type definitions
                raise NotImplementedError
              end
            }
          elsif 'map' == type.name
            property_definition = type if property_definition.nil? #TODO: FIX Hack
            builder.tag!(tag_name){
              value.each do |k,v|
                builder.tag!('entry'){
                  serialize_type builder, nil, property_definition.type_parameters.first, k
                  serialize_type builder, nil, property_definition.type_parameters.last, v
                }
              end
            }
          else
            #process each property of the type
            builder.tag!(tag_name) {
              type.type_attributes.each do |prop_name, prop_property_definition|
                prop_value = value.send(prop_name)
                if prop_value
                  serialize_type builder, prop_property_definition, prop_property_definition.type, prop_value
                end
              end

            }
          end
        end
        builder
      end

      def deserialize_data(node, parent_id, graph, objects_array)
        return nil unless node

        return get_object_from_reference(node.get_attribute('reference').sub('../',''), graph, objects_array, parent_id) if node.has_attribute? 'reference'
        case node.node_name
          when 'map'
            map  = Hash.new
            object_id = add_object_to_graph(map, parent_id, graph, objects_array)
            node.child.each do |entry|
              map[deserialize_data(entry.children.first, object_id, graph, objects_array)] = deserialize_data(entry.children.last, object_id, graph, objects_array)
            end
            return map
          when 'list', 'set'
            list = Array.new
            node.children.each do |item|
              object_id = add_object_to_graph(list, parent_id, graph, objects_array)
              list << deserialize_data(item, object_id, graph, objects_array)
            end
            return list
          when 'boolean'
            return node.text == 'true'
          else
            type = ApiDefinition::PRIMITIVE_TYPES.values.detect {|pt| pt.name == node.node_name}
            if type #if it's primitive
              #for some reason case is being ignored
              return node.text.to_i if type.klass == Integer
              return node.text.to_f if type.klass == Float
              return node.text if type.klass == String
              return Time.parse(node.text) if type.klass == Time
              return nil
            else #its defined by the external api
              type = @api_definition.types[node.node_name]
              unless type
                if node.node_name == "null"
                  return nil
                else
                  raise Com::Korwe::NotImplementedError(node.node_name)
                end
              else
                if type.klass.nil?
                  instance = Hash.new
                  object_id = add_object_to_graph(instance, parent_id, graph, objects_array)
                  type.type_attributes.each do |property_name, property_definition|
                    property_node = node.at_xpath("./#{property_name}")
                    unless property_node.nil?
                      property_node.node_name=@api_definition.types[property_definition.type].name
                      instance[property_name] = deserialize_data(property_node, object_id, graph, objects_array)
                    end
                  end
                else
                  instance = type.klass.new
                  object_id = add_object_to_graph(instance, parent_id, graph, objects_array)
                  type.type_attributes.each do |property_name, property_definition|
                    property_node = node.at_xpath("./#{property_name}")
                    unless property_node.nil?

                      if property_definition.type == 'Object' and property_node.has_attribute?('class')
                        property_node.node_name = property_node.get_attribute('class')
                      else
                        property_node.node_name=@api_definition.types[property_definition.type].name
                      end
                      instance.send("#{property_name}=", deserialize_data(property_node, object_id, graph, objects_array))
                    end
                  end
                end

                return instance
              end
            end
        end
      end

      def get_object_from_reference(reference, graph, object_array, current_id)
        return object_array[current_id] if reference.empty?
        paths = reference.split('/')
        current_object = nil
        paths_length = paths.length-1
        paths.each_with_index do |path,i|
          if path == '..'
            edge = graph.edges.detect { |e| e.source == current_id }
            current_id = edge.target if edge
            current_object = object_array[current_id] if(paths_length == i)
          elsif path.index(/^[A-Z]/) or path.include?('.')
            current_object ||= object_array[current_id]
            index_scan = path.scan(/\[(\d+)\]/)
            if index_scan.empty?
              index = 0
            else
              index = index_scan.first.first.to_i-1 #XPath starts index at 1
            end
            current_object = current_object[index]
          else
            current_object ||= object_array[current_id]
            current_object = current_object.class == Hash ? current_object[path] : current_object.send(path)
          end
        end
        current_object
      end

      def add_object_to_graph(object, parent_id, graph, object_array)

        object_id = object_array.length
        object_array << object
        graph.add_vertex(object_id)
        graph.add_edge(object_id, parent_id) if parent_id
        object_id
      end

    end
  end
end