module Korwe
  module TheCore
    class KillSessionRequest < CoreRequest
      def initialize(session_id)
        super(session_id, :KillSessionRequest)
      end
    end
  end
end
