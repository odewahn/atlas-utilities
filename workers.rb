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

class PermissionWorker

	include Resque::Plugins::Status

  @queue = "permission_worker"

  @logger ||= Logger.new(STDOUT)   
  
  def self.perform(process_id, msg)

    @logger.info "#{@queue} (#{process_id}) => #{msg}"
    # need to create a unique, random screen name.  This is overridden once the user logs in, so we don't really care what it is
    random_name = (0...8).map{(65+rand(26)).chr}.join
    begin
       chimera_user = ChimeraEndpoint.create_user(msg["email"], random_name )
       @logger.info "#{@queue} (#{process_id}) => Created user"
       permission = ChimeraEndpoint.create_book_permission({:user => {:email => msg["email"]}, :book => {:isbn => msg["isbn"]}, :type => "CollaboratorBookPermission"})
       @logger.info "#{@queue} (#{process_id}) => Created permission"
    rescue Exception => e
       @logger.error "#{@queue} (#{process_id}) => #{e}"
    end
  end
  
end

class ChecklistWorker

   include Resque::Plugins::Status

   @queue = "checklist_worker"

   @logger ||= Logger.new(STDOUT)   
   
   # Initialize the github client connection
   @client = Octokit::Client.new(:login => ENV["GITHUB_LOGIN"], :oauth_token => ENV["GITHUB_TOKEN"])
      
   def self.perform(process_id, msg)
     # Do something here
     @logger.info "#{@queue} (#{process_id}) => #{msg}"
   
     # Pull out the template from the checklist repo on github
     c = @client.contents("oreillymedia/checklists",:path => msg["checklist"])
     checklist_text = Base64.decode64(c["content"])

     @logger.info "#{@queue} (#{process_id}) => Pulled checklist"
    
     # Now render the raw markdown checklist and substitute in the variable placeholder names
     message_body = Mustache.render(checklist_text, msg).encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')

     @client.create_issue("odewahn/test-sqs-api", "#{message_body[2..40]}...", message_body)     

     @logger.info "#{@queue} (#{process_id}) => Created issue"
     
   end
   
end
