require File.expand_path('../core_request', __FILE__)
module Korwe
  module TheCore
    class ServiceRequest < CoreRequest

      attr_accessor :function, :params, :location

      def initialize(session_id, function)
        super(session_id, :ServiceRequest)
        self.function = function
        self.params= Hash.new
      end

      def paramNames
        params.keys
      end

      def to_s
        "ServiceRequest{choreography='#{choreography}, function='#{function}', #{params}}"
      end
    end
  end
end
