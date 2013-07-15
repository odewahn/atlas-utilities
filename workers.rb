require "./endpoints"
require 'base64'
require 'mustache'
require 'octokit'
require 'dotenv'
require 'logger'
require 'resque'
require 'resque-status'
require 'gauges'
require 'redis'

Dotenv.load

# To start these, use this command:
#   rake resque:work QUEUE=*


def log(logger, queue, process_id, msg)
  logger.info "#{queue} \t #{process_id} \t #{msg}"
end

class PermissionWorker

	include Resque::Plugins::Status
  @queue = "permission_worker"
  @logger ||= Logger.new(STDOUT)     

  def self.perform(process_id, msg)
    log(@logger, @queue, process_id, "Attempting to add permission #{msg}")
    begin
       # need to create a unique, random screen name.  This is overridden once the user logs in, so we don't really care what it is
       random_name = (0...8).map{(65+rand(26)).chr}.join
       # First create a new user in Chimera
       # If the user already exists, this just does nothing
       chimera_user = ChimeraEndpoint.create_user(msg["email"], random_name )
       log(@logger, @queue, process_id, "Created User")
       # Now add the permission to the book to this new user
       # What if the book doesn't exist???
       permission = ChimeraEndpoint.create_book_permission({:user => {:email => msg["email"]}, :book => {:isbn => msg["isbn"]}, :type => "CollaboratorBookPermission"})
       log(@logger, @queue, process_id, "Created permission")
    rescue Exception => e
       log(@logger, @queue, process_id, "ERROR #{e}")
       raise e
    end
  end
  
end

class ChecklistWorker

   include Resque::Plugins::Status
   @queue = "checklist_worker"
   @logger ||= Logger.new(STDOUT)   
   @github_client ||= Octokit::Client.new(:login => ENV["GITHUB_LOGIN"], :oauth_token => ENV["GITHUB_TOKEN"])
   
   def self.perform(process_id, msg)
     log(@logger, @queue, process_id, "Attempting to create checklist #{msg}")
     begin
       # Pull out the template from the checklist repo on github and process the variables using mustache
       c = @github_client.contents("oreillymedia/checklists",:path => msg["checklist"])
       checklist_text = Base64.decode64(c["content"])
       message_body = Mustache.render(checklist_text, msg).encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')
       log(@logger, @queue, process_id, "Retrieveved checklist and performed processed it with mustache template")
       @github_client.create_issue("odewahn/test-sqs-api", "#{message_body[2..40]}...", message_body)     
       log(@logger, @queue, process_id, "Created new github issue")
     rescue Exception => e
        log(@logger, @queue, process_id, "Could not connect to github API - #{e}")
        raise e
     end
     
   end
   
end

class GaugesWorker
  
  include Resque::Plugins::Status
  @queue = "gauges_worker"
  @logger ||= Logger.new(STDOUT)   
  @client = Gauges.new(:token => ENV['GAUGES_TOKEN'])
  
  uri = URI.parse(ENV["REDIS_URL"])
  @redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    
  def self.perform(process_id, msg)
     log(@logger, @queue, process_id, "Attempting to grab gauges data for #{msg}")
     begin
        date = msg["date"].length > 0 ? msg["date"] : Time.now.strftime("%Y-%m-%d")
        max_pages = msg["max_pages"].length > 0 ? msg["max_pages"].to_i : 20
        for idx in 1..max_pages
           key = "chimera:#{date}:#{idx}"
           if !@redis.exists(key)
              log(@logger, @queue, process_id, "Trying key #{key}")  
              p = @client.content(ENV["GAUGES_ID"], {:date => date, :page => idx} )
              @redis.set(key,p)
              # make sure these only persist about an hour
              @redis.expire(key, 3600) 
              log(@logger, @queue, process_id, "Wrote #{key} with #{p['content'].count} results")  
           end
        end         
     rescue Exception => e
        log(@logger, @queue, process_id, "The following error occurred: #{e}")
        raise e
     end
     
  end

end
