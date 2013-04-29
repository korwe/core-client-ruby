module Korwe
  module TheCore
    class CoreSubscriber
      def initialize(session, serializer, queue, filter)
        @serializer = serializer
        @session = session
        queue_name = "#{queue.queue_name}.#{filter}"
        address = Qpid::Messaging::Address.new "#{queue_name};{create:always, mode:consume, delete:receiver, node:{type: queue, x-bindings: [{exchange: core.topic, queue: #{queue_name}, key: #{queue_name}}]}}"
        @receiver = @session.create_receiver address
        @receiver.capacity=10
      end

      def get_response
        response = @receiver.get(Qpid::Messaging::Duration.new(10000))
        if response and response.content and not response.content.empty?
          @session.acknowledge response
          core_message = @serializer.deserialize(response.content)
          handle_error_response(core_message) unless core_message.successful
          core_message
        else
          puts "No response from server"
        end
      end

      def close
        @receiver.close unless @receiver.closed?
      end

      def handle_error_response(message)
        puts "Request was unsuccessful with error(#{message.error_code}): #{message.error_message}"
      end
    end
  end
end