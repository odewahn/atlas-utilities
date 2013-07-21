require 'sinatra'
require 'resque'
require 'resque-status'
require 'json'
require './workers'
require 'dotenv'
require 'redis'

Dotenv.load


# Point to the correct 
uri = URI.parse(ENV["REDIS_URL"])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :thread_safe => true)

redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :thread_safe => true)


#**********************************************************************
# Adds redirection for HTTP to HTTPS
#**********************************************************************
get '/*.json' do
  pass if request.secure?
  content_type :json
  '{ "message" : "You are using http. Please use https" }'
end

get '/*' do
  pass if ENV["ENVIRONMENT"] == "development"
  if request.secure?
    pass
  else
   halt 404
  end
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
  job = PermissionWorker.create(msg)
  JSON.pretty_generate( { :id => job } )
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
  job = ChecklistWorker.create(msg)
  JSON.pretty_generate( { :id => job} )

end

#**********************************************************************
# This section handles code related to stuffing gauges data into a table
#**********************************************************************
get "/gauges" do
  erb :gauges
end

get "/gauges/:date" do
  if redis.exists("chimera:#{params[:date]}")
     JSON.pretty_generate(eval(redis.get("chimera:#{params[:date]}")))
  else
     halt 404
  end
end


post "/gauges" do
  msg = {
    :date => params[:date], 
    :gauge => params[:gauge],
    :max_pages => params[:max_pages]

  }
  job = GaugesWorker.create(msg)
  JSON.pretty_generate( { :id => job} )
end

#**********************************************************************
# This section handles code related to adding a webhook to a repo
#**********************************************************************
get "/webhook" do
  erb :webhook
end

post "/webhook" do
  msg = {
    :repo => params[:repo], 
    :callback => params[:callback]
  }
  job = WebhookWorker.create(msg)
  JSON.pretty_generate( { :id => job} )
end

post "/pull_request_alert" do
  msg = {
    :payload => params[:payload]
  }
  job = CLAWorker.create(msg)
  JSON.pretty_generate( { :id => job} )
end
