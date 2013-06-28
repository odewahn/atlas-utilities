$: << File.expand_path(File.dirname(__FILE__))

require './app.rb'
require 'resque/server'

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" => Resque::Server.new