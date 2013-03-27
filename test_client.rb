require 'builder'
require 'eventmachine'
require 'qpid_messaging'
require File.expand_path('../messages/core_message',__FILE__)
require File.expand_path('../messages/core_response',__FILE__)
Dir[File.expand_path('../messages/*',__FILE__)].each {|f| require f}
require File.expand_path('../api/core_config', __FILE__)
require File.expand_path('../api/message_queue', __FILE__)
require File.expand_path('../api/core_subscriber', __FILE__)
require File.expand_path('../api/core_client', __FILE__)


include Korwe::TheCore


session_id = 'my-session-id'
message = ServiceRequest.new(session_id,'fetchLatest')
message.choreography='SyndicationService'
message.params['maxEntries'] = 5
message.params['feedUrl'] = 'http://feeds.bbci.co.uk/news/rss.xml'

client = CoreClient.new
client.connect
client.init_session(session_id)
response_message = client.make_data_request(message)
client.end_session(session_id)



