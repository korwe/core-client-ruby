module Korwe
  module TheCore
    class ServiceResponse < CoreResponse
      attr_accessor :data_available
      def initialize(session_id, guid, successful, hasData)
        super(session_id, :ServiceResponse, guid, successful)
        self.data_available= hasData
      end
    end
  end
end