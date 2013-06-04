require File.expand_path('../core_response', __FILE__)
module Korwe
  module TheCore
    class ServiceResponse < CoreResponse
      attr_accessor :data_available
      def initialize(session_id, guid, successful, has_data)
        super(session_id, :ServiceResponse, guid, successful)
        self.data_available= has_data
      end

      def data_available?
        data_available
      end
    end
  end
end