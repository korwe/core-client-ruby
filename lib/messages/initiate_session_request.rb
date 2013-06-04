require File.expand_path('../core_request', __FILE__)
module Korwe
  module TheCore
    class InitiateSessionRequest < CoreRequest
      def initialize(session_id)
        super(session_id, :InitiateSessionRequest)
      end
    end
  end
end
