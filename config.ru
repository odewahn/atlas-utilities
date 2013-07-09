#$: << File.expand_path(File.dirname(__FILE__))
require './app.rb'
require 'resque/server'
require 'dotenv'
require 'sinatra'
Dotenv.load

#**********************************************************************
# Adds redirection for HTTP to HTTPS
#**********************************************************************
get '/*.json' do
  pass if request.secure?
  content_type :json
  '{ "message" : "You are using http. Please use https" }'
end

get '/*' do
  halt 404 unless request.secure?
end

# Set up very simple, simple auth!
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == [ENV["UTILITY_USERNAME"], ENV["UTILITY_PASSWORD"]]
end

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" =>  Resque::Server.new



  
   
