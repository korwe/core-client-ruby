module Korwe
  module TheCore
    class CoreError < RuntimeError
      attr_accessor :error_code, :error_message

      def initialize(error_code, error_message)
        self.error_code=error_code
        self.error_message=error_message
      end
    end


  end
end