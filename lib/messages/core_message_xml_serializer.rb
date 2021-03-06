require 'builder'
require 'nokogiri'
require 'rgl/adjacency'

module Korwe
  module TheCore
    class CoreMessageXmlSerializer

      attr_reader :api_definition

      TIMESTAMP_FORMAT = '%Y%m%dT%H%M%S.%L'

      def initialize(api_definition_path)
        @api_definition = ApiDefinition.new(api_definition_path)
      end

      def serialize(message)
        LOG.debug "Serializing message #{message}"
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
              b.location(message.location) if message.location
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
        builder.target!
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
        builder.errorType(message.error_type)
        builder.errorCode(message.error_code)
        builder.errorMessage(message.error_message)
        builder.successful(message.successful ? '1' : '0')
      end

      def set_response_fields(node, core_message)
        core_message.error_type = node_value(node, 'errorType')
        core_message.error_code = node_value(node, 'errorCode')
        core_message.error_message = node_value(node, 'errorMessage')

        error_vars_node = node.at_css('errorVars')
        if error_vars_node and error_vars_node.children.length > 0
          core_message.error_vars = []
          error_vars_node.children.each do |error_var_node|
            core_message.error_vars << error_var_node.text
          end
        end

      end

      def node_value(node, css)
        found_node = node.at_css(css)
        found_node.nil? ? nil : found_node.text
      end

      def serialize_request_function(builder, message)
        service_definition = @api_definition.services[message.choreography]
        raise CoreClientError.new("api.service.undefined", nil, [message.choreography]) unless service_definition

        function_definition = service_definition.method_list[message.function]
        raise CoreClientError.new("api.service.function.undefined", nil, [message.choreography, message.function]) unless function_definition

        builder.function(function_definition.name)
        builder.parameters {
          message.params.each do |param_name,param_value|
            type_name = function_definition.parameters[param_name]
            type_name = @api_definition.global_parameters[param_name] if !type_name and @api_definition.global_parameters.key?(param_name) and param_value #Check global parameters

            raise CoreClientError.new("api.service.function.parameter.undefined", nil, [message.choreography, message.function, param_name]) unless type_name

            builder.parameter {
              builder.name param_name
              type_builder = Builder::XmlMarkup.new
              builder.value serialize_type(type_builder, nil, type_name, param_value, ["/#{@api_definition.types[type_name].name}"], {})
            }
          end
        }
      end

      def serialize_type(builder, property_definition, type_name, value, path_stack, ref_map)
        type = @api_definition.types[type_name]

        tag_name = property_definition.nil? ? type.name : property_definition.name
        reference = object_reference_path(ref_map, value)

        if ApiDefinition::PRIMITIVE_TYPES.keys.any?{|k| k==type_name}
          if 'DateTime' == type.name
            builder.__send__ tag_name, value.strftime(TIMESTAMP_FORMAT)
          else
            if property_definition.nil?
              builder.__send__ tag_name, value.to_s
            else
              builder.__send__ tag_name, value.to_s, :class=>@api_definition.types[property_definition.type].name
            end
          end
        else
          if reference.nil?
            add_object_to_reference_map(ref_map, path_stack, value)
          else #create element with reference and return
            return builder.tag!(tag_name, :reference=>reference)
          end

          if ['list', 'set'].any? {|k| k==type.name}
            builder.tag!(tag_name) {
              property_definition = type if property_definition.nil?
              prop_tag_name = @api_definition.types[property_definition.type_parameters.first].name
              value.each_with_index do |o,i|
                serialize_type builder, nil, property_definition.type_parameters.first, o, (path_stack +[prop_tag_name+ (i==0? '': "[#{i+1}]")]), ref_map
              end
            }
          elsif 'map' == type.name
            property_definition = type if property_definition.nil? #TODO: FIX Hack
            builder.tag!(tag_name){
              value.each_with_index do |kv,i|
                path_stack << 'entry'+ (i==0? '': "[#{i+1}]")

                prop_key_tag_name = @api_definition.types[property_definition.type_parameters.first].name
                prop_val_tag_name = @api_definition.types[property_definition.type_parameters.first].name
                builder.tag!('entry'){
                  serialize_type builder, nil, property_definition.type_parameters.first, kv[0], (path_stack+[prop_key_tag_name]), ref_map
                  serialize_type builder, nil, property_definition.type_parameters.last, kv[1], (path_stack+[prop_val_tag_name]), ref_map
                }
                path_stack.pop
              end
            }
          else #process each property of the type
            attributes = {}
            #Change to concrete type, if current type is inherited
            if type.inherited
              type = @api_definition.types[api_classname(value.class)]
              attributes[:class] = type.name
            end
            builder.tag!(tag_name, attributes) {
              type.type_attributes.each do |prop_name, attribute_definition|
                prop_value = value.send(prop_name)
                if prop_value
                  serialize_type builder, attribute_definition, attribute_definition.type, prop_value, path_stack+[prop_name], ref_map
                end
              end
            }
          end
        end
        builder.target!
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
          when 'list', 'set', 'linked-hash-set'
            list = Array.new
            node.children.each do |item|
              object_id = add_object_to_graph(list, parent_id, graph, objects_array)
              list << deserialize_data(item, object_id, graph, objects_array)
            end
            return list
          when /\[\]/ #handle arrays
            return node.text if node.node_name.downcase.include? 'byte' #handle byte arrays

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
            else # it's defined by the external api
              type = @api_definition.types[node.node_name]
              unless type
                if node.node_name == "null"
                  return nil
                else
                  raise Korwe::TheCore::NotImplementedError(node.node_name)
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
                  node.children.each do |child_node|
                    property_name = child_node.name
                    property_definition = type.type_attributes[property_name]
                    if type.type_attributes.has_key? property_name
                      property_type = @api_definition.types[property_definition.type]

                      raise CoreClientError.new("api.type.undefined", "Type [#{property_definition.type}] not undefined", [property_definition.type]) unless property_type

                      if property_type.inherited and child_node.has_attribute?('class')
                        child_node.node_name = child_node.get_attribute('class')
                      else
                        child_node.node_name=property_type.name
                      end
                      instance.send("#{property_name}=", deserialize_data(child_node, object_id, graph, objects_array))
                    else
                      LOG.warn "No attribute[#{property_name}] found for #{type.name} in api-definition, skipping"
                    end

                  end
                end
                return instance
              end
            end
        end
      end

      #
      # Serialization
      #

      def object_reference_path(ref_map, reference_object)
        return nil if reference_object.nil? #no reference_object therefore no object reference

        reference = ref_map[reference_object.object_id]

        #Currently we only support absolute references - TODO: Implement relative references


      end

      def add_object_to_reference_map(ref_map, path, object)
        return if path.nil?
        #return path
        ref_map[object.object_id] = path.join('/')
      end

      #
      # Deserialization
      #

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
              index = index_scan.first.first.to_i-1 #XPath starts index at 1, value
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

      def api_classname(klass)
        klass_name_path = klass.to_s.split('::')
        klass_name_path = klass_name_path[0..-2].collect(&:downcase) << klass_name_path.last
        klass_name_path.join('.')
      end

    end
  end
end
