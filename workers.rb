require "./endpoints"
require 'base64'
require 'mustache'
require 'octokit'
require 'dotenv'
require 'logger'

Dotenv.load

# To start these, use this command:
#   rake resque:work QUEUE=*

class PermissionWorker
  @queue = "permission_worker"
  
  def self.perform(permission)
    # need to create a unique, random screen name.  This is overridden once the user logs in, so we don't really care what it is
    random_name = (0...8).map{(65+rand(26)).chr}.join
    chimera_user = ChimeraEndpoint.create_user(permission["email"], random_name )
    permission = ChimeraEndpoint.create_book_permission({:user => {:email => permission["email"]}, :book => {:isbn => permission["isbn"]}, :type => "CollaboratorBookPermission"})
  end
  
end

class ChecklistWorker
   @queue = "checklist_worker"

   @logger ||= Logger.new(STDOUT)   
   
   # Initialize the github client connection
   @client = Octokit::Client.new(:login => ENV["GITHUB_LOGIN"], :oauth_token => ENV["GITHUB_TOKEN"])
      
   def self.perform(msg)
     # Do something here
     @logger.info "Got checklist request: #{msg}"
   
     # Pull out the template from the checklist repo on github
     c = @client.contents("oreillymedia/checklists",:path => msg["checklist"])
     checklist_text = Base64.decode64(c["content"])
    
     # Now render the raw markdown checklist and substitute in the variable placeholder names
     message_body = Mustache.render(checklist_text, msg).encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')

     @client.create_issue("odewahn/test-sqs-api", "#{message_body[2..40]}...", message_body)     
     
   end
   
end
