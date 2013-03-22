require 'builder'
require 'nokogiri'
require 'time'

module Korwe
  module TheCore
    class CoreMessageXmlSerializer

      TIMESTAMP_FORMAT = '%Y%m%dT%H%M%S.%L'
      def serialize(message)
        builder = Builder::XmlMarkup.new(:indent=>2)

        builder.coreMessage do |b|
          b.sessionId(message.session_id)
          b.messageType(message.message_type.to_s)
          b.guid(message.guid)
          b.choreography(message.choreography)
          b.description(message.description)
          b.timeStamp(message.timestamp.strftime(TIMESTAMP_FORMAT))

          case message.message_type
            when :ServiceRequest
              b.function(message.function)
              b.parameters do |pb|
                message.params.each do |k,v|
                  pb.name(k)
                  pb.value(v)
                end
              end
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
        document = Nokogiri::XML::Document.parse(message_string, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS)
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
            data = node_value(root, 'data')
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
    end
  end
end