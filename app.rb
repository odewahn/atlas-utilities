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


#**********************************************************************
# This section handles code related to adding a permission to an account
#**********************************************************************
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


#**********************************************************************
# This section handles code related to sending a checklist
#**********************************************************************
get "/checklist" do
  erb :checklist
end

post "/checklist" do
  msg = {
    :user_id => params[:user_id], 
    :isbn => params[:isbn],
    :checklist => params[:checklist],
    :body => params[:body]
  }
  Resque.enqueue(ChecklistWorker, msg)
end