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

      def connect(api_definition_path)
        @serializer = CoreMessageXmlSerializer.new(api_definition_path)
        @connection = Messaging::Connection.new
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
        puts "SENDING: #{request.content}"


          response_subscriber = CoreSubscriber.new(@session, @serializer, MessageQueue::CoreToClient, message.session_id)
          @sender.send(request)
        begin
          response_subscriber.get_response
        rescue Exception => e
          puts "Error retreiving message from server: #{e}"
          raise e
        ensure
          response_subscriber.close
        end
      end

      def make_data_request(message)
        return puts("Error sending message: Requires session id") unless message.session_id

        data_subscriber = CoreSubscriber.new(@session, @serializer, MessageQueue::Data, message.session_id)
        response_message = make_request(message)
        begin
          data_message = data_subscriber.get_response

          class << response_message
            attr_accessor :data
          end
          response_message.data = data_message.data
          response_message
        rescue Exception => e
          puts "Error retreiving message from server: #{e}"
          raise e
        ensure
          data_subscriber.close
        end
      end
    end
  end
end

