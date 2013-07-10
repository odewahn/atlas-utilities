require "./endpoints"
require 'base64'
require 'mustache'
require 'octokit'
require 'dotenv'
require 'logger'
require 'resque'
require 'resque-status'

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
