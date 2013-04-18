require "core-client-ruby/version"
require 'builder'
require 'qpid_messaging'
require File.expand_path('../messages/core_message',__FILE__)
require File.expand_path('../messages/core_response',__FILE__)
Dir[File.expand_path('../messages/*',__FILE__)].each {|f| require f}
require File.expand_path('../api/message_queue', __FILE__)
require File.expand_path('../api/core_subscriber', __FILE__)
require File.expand_path('../api/api_definition', __FILE__)
require File.expand_path('../api/core_client', __FILE__)


module Core
  module Client
    module Ruby
      # Your code goes here...
    end
  end
end
