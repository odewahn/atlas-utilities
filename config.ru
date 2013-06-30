$: << File.expand_path(File.dirname(__FILE__))
require './app.rb'
require 'resque/server'

# Set up very simple, simple auth!
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == ['atlas', 'tarsier']
end

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" =>  Resque::Server.new



  
   
