# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'core-client-ruby/version'

Gem::Specification.new do |gem|
  gem.name          = "core-client"
  gem.version       = Core::Client::Ruby::VERSION
  gem.authors       = ["tjad"]
  gem.email         = ["tjad.clark@korwe.com"]
  gem.description   = %q{Korwe's client for The Core }
  gem.summary       = %q{A ready to use interface into Korwe's `The Core` Platform}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]


  #Dependencies
  gem.add_dependency 'builder', '>=3.2.0'
  gem.add_dependency 'nokogiri', '>=1.5.9'
  gem.add_dependency 'rgl', '>=0.4.0'
  gem.add_dependency 'qpid_messaging', '>=0.20.2'
end
