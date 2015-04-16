module Korwe
  module TheCore
    class CoreClient
      include Qpid

      def initialize
        @sender_queue_definition = MessageQueue::ClientToCore
        @data_queue_definition = MessageQueue::Data
        @message_cache = Hash.new
        @data_cache = Hash.new
      end

      def connect(core_config, api_definition_path)
        @serializer = CoreMessageXmlSerializer.new(api_definition_path)
        @connection = Messaging::Connection.new core_config
        @connection.open
        @session = @connection.create_session
        @sender = @session.create_sender(@sender_queue_definition.queue_name)
      end

      def close
        @connection.close if @connection and @connection.open?
      end

      def init_session(session_id)
        message = InitiateSessionRequest.new(session_id)
        make_request(message)
        puts "Session created"
      end

      def end_session(session_id)
        message = KillSessionRequest.new(session_id)
        make_request(message)
        puts "Session killed"
      end

      def make_request(message)
        return puts("Error sending message: Requires session id") unless message.session_id

        request = Messaging::Message.new
        request.content = @serializer.serialize(message)
        request['choreography'] = message.choreography
        request['guid'] = message.guid
        request['messageType'] = message.message_type
        request['sessionId'] = message.session_id
        puts "SENDING: #{request.content}"

        response_subscriber = CoreSubscriber.new(@session, @serializer, MessageQueue::CoreToClient, message.session_id)
        @sender.send(request)
        begin
          response_subscriber.get_response
        rescue MessagingError => qme
          handle_qpid_messaging_error qme
        ensure
          response_subscriber.close
        end
      end

      def make_data_request(message)
        unless message.session_id
          puts('Error sending message: Requires session id')
          raise CoreClientError.new('session.required', 'A session is required')
        end

        begin
          data_subscriber = CoreSubscriber.new(@session, @serializer, MessageQueue::Data, message.session_id)
          response_message = make_request(message)
          data_message = data_subscriber.get_response

          class << response_message
            attr_accessor :data
          end
          response_message.data = data_message.data
          response_message
        rescue CoreError => ce
          raise ce
        rescue MessagingError => qme
          handle_qpid_messaging_error qme
        rescue Exception => e
          puts "Error retreiving data message from server: #{e}"
          raise e
        ensure
          data_subscriber.close if data_subscriber
        end

      end

      def handle_qpid_messaging_error qme
        if qme.message.eql? 'No message to fetch'
          raise CoreClientError.new('noResponse', 'There was no response from server')
        elsif qme.message.start_with? 'resource-deleted'
          raise CoreClientError.new('queue.deleted', 'Message queue was deleted')
        else
          puts "Messaging error >>> #{qme}"
          raise CoreClientError.new('noResponse', 'Unknown messaging error')
        end
      end
    end
  end
end

