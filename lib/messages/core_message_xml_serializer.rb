require 'builder'
require 'nokogiri'

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
            data = data_text.nil? ? nil : deserialize_data(Nokogiri::XML(data_text, nil, 'UTF-8', Nokogiri::XML::ParseOptions::NOBLANKS).child)
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
              builder.value serialize_type(type_builder, function_definition.parameters[param_name], param_value).target!
            }
          end
        }
      end

      def serialize_type(builder, type_name, value)
        type = @api_definition.types[type_name]
        if ApiDefinition::PRIMITIVE_TYPES.keys.any?{|k| k==type_name}
          builder.__send__ type.name, value.to_s
        else
          builder.tag!(type.name) {
            #process each property of the type
            type.type_properties.each do |prop_name, prop_type|
              prop_value = value.send(prop_name)
              if prop_value
                if ApiDefinition::PRIMITIVE_TYPES.keys.any?{|k| k==prop_type} #If primitive
                  builder.__send__ prop_name, prop_value.to_s
                else
                  serialize_type builder, prop_type, prop_value
                end
              end
            end
          }
        end
        builder
      end

      def deserialize_data(root)
        return nil unless root

        case root.node_name
          when 'map'
            map  = Hash.new
            root.child.each do |entry|
              map[deserialize_data(entry.children.first)] = deserialize_data(entry.children.last)
            end
            return map
          when 'list', 'set'
            list = Array.new
            root.children.each do |item|
              list << deserialize_data(item)
            end
            return list
          when 'boolean'
            return root.text == 'true'
          else
            type = ApiDefinition::PRIMITIVE_TYPES.values.detect {|pt| pt.name == root.node_name}
            if type #if it's primitive
              #for some reason case is being ignored
              return root.text.to_i if type.klass == Integer
              return root.text.to_f if type.klass == Float
              return root.text if type.klass == String
              return Time.parse(root.text) if type.klass == Time
              return nil
            else #its defined by the external api
              type = @api_definition.types[root.node_name]
              unless type #Not defined at all, TODO: Perhaps raise error
                return nil
              else
                if type.klass.nil?
                  instance = Hash.new
                  type.type_properties.each do |property_name, property_type|
                    property_node = root.at_xpath("./#{property_name}")
                    unless property_node.nil?
                      property_node.node_name=@api_definition.types[property_type].name
                      instance[property_name] = deserialize_data(property_node)
                    end
                  end
                else
                  instance = type.klass.new
                  type.type_properties.each do |property_name, property_type|
                    property_node = root.at_xpath("./#{property_name}")
                    unless property_node.nil?
                      property_node.node_name=@api_definition.types[property_type].name
                      instance.send("#{property_name}=", deserialize_data(property_node))
                    end
                  end
                end

                return instance
              end
            end
        end
      end

    end
  end
end