#The following message types are acceptable
#UnknownMessageType
#InitiateSessionRequest
#KillSessionRequest
#ServiceRequest
#InitiateSessionResponse
#KillSessionResponse
#ServiceResponse
#DataResponse

module Korwe
  module TheCore
    class CoreMessage
      attr_accessor :session_id, :description, :choreography, :guid, :timestamp, :message_type

      def initialize(session_id, message_type)
        self.session_id = session_id
        self.message_type = message_type
        self.description = "Session Id: #{session_id} Type: #{message_type}"
      end
    end
  end
end
