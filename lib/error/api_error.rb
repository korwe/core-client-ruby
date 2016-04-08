require File.expand_path('../core_error',__FILE__)
module Korwe
  module TheCore
    class NotImplementedError < Exception
      attr_accessor :klass_name

      def initialize(klass_name=nil)
        self.klass_name=klass_name
      end

      def to_s
        "NotImplementedError: #{klass_name}"
      end
    end
  end
end
