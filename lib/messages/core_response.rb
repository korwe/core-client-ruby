require File.expand_path('../core_message', __FILE__)
module Korwe
  module TheCore
    class CoreResponse < CoreMessage
      attr_accessor :successful, :error_type, :error_code, :error_message, :error_vars

      def initialize(session_id, message_type, guid, successful)
        super(session_id, message_type)
        self.guid= guid
        self.successful=successful
      end
    end
  end
end
