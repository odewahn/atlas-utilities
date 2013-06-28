require 'sinatra'
require 'resque'
require 'json'
require './workers'
require 'dotenv'

Dotenv.load


# Point to the correct 
uri = URI.parse(ENV["REDIS_URL"])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :thread_safe => true)

# Set up very simple, simple auth!
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == ['atlas', 'tarsier']
end


get "/permission" do
  erb :permission
end


# Post a message into the queue
post "/permission" do
  msg = { 
    :email => params[:email], 
    :isbn => params[:isbn]
  }
  Resque.enqueue(PermissionWorker, msg)
end