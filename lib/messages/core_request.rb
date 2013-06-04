require 'securerandom'
require File.expand_path('../core_message', __FILE__)
module Korwe
  module TheCore
    class CoreRequest < CoreMessage
      def initialize(session_id, message_type)
        super(session_id, message_type)
        self.guid = SecureRandom.uuid
      end
    end
  end
end