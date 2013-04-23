module Korwe
  module TheCore
    class CoreError < RuntimeError
      attr_accessor :error_code, :error_message
    end
  end
end