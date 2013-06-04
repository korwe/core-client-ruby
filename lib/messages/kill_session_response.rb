require File.expand_path('../core_response', __FILE__)
module Korwe
  module TheCore
    class KillSessionResponse < CoreResponse
      def initialize(session_id, guid, successful)
        super(session_id, :KillSessionResponse, guid, successful)
      end
    end
  end
end
