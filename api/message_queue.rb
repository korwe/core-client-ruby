module Korwe
  module TheCore
    class MessageQueue
      attr_accessor :queue_name, :type

      def initialize(queue_name, routing_type)
        self.queue_name= queue_name
        self.type=routing_type
      end

      def topic?
        :type == :topic
      end

      def direct?
        :type == :direct
      end

      DIRECT_EXCHANGE = 'core.direct'
      TOPIC_EXCHANGE = 'core.topic'

      ClientToCore = new('core.client-core', :direct)
      CoreToService = new('core.core-service', :topic)
      ServiceToCore = new('core.service-core', :direct)
      CoreToClient = new('core.core-client', :topic)
      CoreToSession = new('core.core-session', :topic)
      Data = new('core.data', :topic)

      #departure -> arrival
      QueuePairs = {ClientToCore=>CoreToClient, CoreToService=>ServiceToCore}

    end
  end
end
