require File.expand_path('../core_error',__FILE__)
module Korwe
  module TheCore
    class NotImplemented
      attr_accessor :klass_name

      def initialize(klass_name=nil)
        self.klass_name=klass_name
      end
    end
  end
end