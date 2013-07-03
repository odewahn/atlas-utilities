#$: << File.expand_path(File.dirname(__FILE__))
require './app.rb'
require 'resque/server'
require 'dotenv'
Dotenv.load


# Set up very simple, simple auth!
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == [ENV[UTILITY_USERNAME], ENV[UTILITY_PASSWORD]]
end

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" =>  Resque::Server.new



  
   
