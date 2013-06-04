require File.expand_path('../core_response', __FILE__)
module Korwe
  module TheCore
    class InitiateSessionResponse < CoreResponse
      def initialize(session_id, guid, successful)
        super(session_id, :InitiateSessionResponse, guid, successful)
      end
    end
  end
end