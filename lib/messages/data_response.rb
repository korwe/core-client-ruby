module Korwe
  module TheCore
    class DataResponse < CoreResponse
      attr_accessor :data
      def initialize(session_id, guid, data)
        super(session_id, :DataResponse, guid, true)
        self.data= data
      end
    end
  end
end
