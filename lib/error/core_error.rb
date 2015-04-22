module Korwe
  module TheCore
    class CoreError < Exception
      attr_accessor :error_type, :error_code, :error_message, :error_vars

      def initialize(error_type, error_code, error_message, error_vars=nil)
        self.error_type=error_type
        self.error_code=error_code
        self.error_message=error_message
        self.error_vars=error_vars
      end

      def self.from_error_type(error_type, error_code, error_message, error_vars=nil)
        case error_type.to_i
          when 1001 then CoreSystemError.new(error_code, error_message, error_vars)
          when 1002 then CoreValidationError.new(error_code, error_message, error_vars)
          when 1003 then CoreServiceError.new(error_code, error_message, error_vars)
          when 1004 then CoreClientError.new(error_code, error_message, error_vars)
        end
      end
    end

    class CoreSystemError < CoreError
      def initialize(error_code, error_message, error_vars=nil)
        super(1001, error_code, error_message, error_vars)
      end
    end

    class CoreValidationError < CoreError
      def initialize(error_code, error_message, error_vars=nil)
        super(1002, error_code, error_message, error_vars)
      end

    end

    class CoreServiceError < CoreError
      def initialize(error_code, error_message, error_vars=nil)
        super(1003, error_code, error_message, error_vars)
      end

    end


    class CoreClientError < CoreError
      def initialize(error_code, error_message, error_vars=nil)
        super(1004, error_code, error_message, error_vars)
      end

    end


  end
end