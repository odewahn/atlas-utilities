require 'sinatra'
require 'resque'
require 'resque-status'
require 'json'
require './workers'
require 'dotenv'

Dotenv.load


# Point to the correct 
uri = URI.parse(ENV["REDIS_URL"])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :thread_safe => true)


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