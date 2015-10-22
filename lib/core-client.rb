require "core-client-ruby/version"
require 'builder'
require 'qpid_messaging'
require 'logger'
require File.expand_path('../error/core_error',__FILE__)
require File.expand_path('../messages/core_message',__FILE__)
require File.expand_path('../messages/core_response',__FILE__)
Dir[File.expand_path('../messages/*',__FILE__)].each {|f| require f}
require File.expand_path('../api/message_queue', __FILE__)
require File.expand_path('../api/core_subscriber', __FILE__)
require File.expand_path('../api/api_definition', __FILE__)
require File.expand_path('../api/core_client', __FILE__)


module Korwe
  module TheCore
    LOG = Logger.new(STDOUT)
    conn = Qpid::Messaging::Connection.new :url => "some.random.messaging.address.to.create.MessageError"
    conn.open
  rescue MessagingError => e
    LOG.warn "fix bypass"
  end
end
module Core
  module Client
    module Ruby
      # Your code goes here...
    end
  end
end
