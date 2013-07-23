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


# This worker adds a webhook to the specified repo.
class WebhookWorker

  include Resque::Plugins::Status
  @queue = "webhook_worker"
  @logger ||= Logger.new(STDOUT)   
  @github_client ||= Octokit::Client.new(:login => ENV["GITHUB_LOGIN"], :oauth_token => ENV["GITHUB_TOKEN"])
  
  def self.perform(process_id, msg)
    log(@logger, @queue, process_id, "Attempting to add webhook #{msg}")
    begin
       @github_client.create_hook(
         msg["repo"],
         'web',
         {
           :url => msg["callback"],
           :content_type => 'json'
         },
         {
           :events => ['pull_request'],
           :active => true
         }
       )
       log(@logger, @queue, process_id, "Created webhook")
    rescue Exception => e
       log(@logger, @queue, process_id, "Could not connect to github API - #{e}")
       raise e
    end
  end
end

# This worker responds to a pull request sent to a repo and sends a CLS
class CLAWorker

  include Resque::Plugins::Status
  @queue = "cla_worker"
  @logger ||= Logger.new(STDOUT)   
  @github_client ||= Octokit::Client.new(:login => ENV["GITHUB_LOGIN"], :oauth_token => ENV["GITHUB_TOKEN"])
  
  def self.perform(process_id, msg)
    dat = {
       "issue_url" => msg["body"]["pull_request"]["issue_url"],
       "sender" => msg["body"]["sender"]["login"],
       "sender_url" => msg["body"]["sender"]["url"],
       "body" => msg["body"]["pull_request"]["body"],
       "diff_url" => msg["body"]["pull_request"]["diff_url"],
       "base" => {
          "url" => msg["body"]["pull_request"]["base"]["repo"]["html_url"],
          "description" => msg["body"]["pull_request"]["base"]["repo"]["description"],
          "full_name" => msg["body"]["pull_request"]["base"]["repo"]["full_name"],
          "owner" => msg["body"]["pull_request"]["base"]["repo"]["owner"]["login"],
          "owner_url" => msg["body"]["pull_request"]["base"]["repo"]["owner"]["url"]
       },
       "request" => {
          "url" => msg["body"]["pull_request"]["head"]["repo"]["html_url"],
          "description" => msg["body"]["pull_request"]["head"]["repo"]["description"],
          "full_name" => msg["body"]["pull_request"]["head"]["repo"]["full_name"],
          "owner" => msg["body"]["pull_request"]["head"]["repo"]["owner"]["login"],
          "owner_url" => msg["body"]["pull_request"]["head"]["repo"]["owner"]["url"]
       }
    }
    log(@logger, @queue, process_id, "The payload for the template is #{dat}")
    # Pull out the template from the checklist repo on github and process the variables using mustache
    c = @github_client.contents("oreillymedia/checklists", {:path => "legal/cla_missing.md"})
    checklist_text = Base64.decode64(c["content"])
    log(@logger, @queue, process_id, "The raw message is #{checklist_text}")
    message_body = Mustache.render(checklist_text, dat).encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')
    @github_client.create_issue(dat["base"]["full_name"], "ALERT! Atlas account required from #{dat["sender"]}", message_body)     
    
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
        total_views = 0
        total_book_views = 0
        summary = {}
        for idx in 1..max_pages
          log(@logger, @queue, process_id, "Fetching page #{idx}")
          p = @client.content(ENV["GAUGES_ID"], {:date => date, :page => idx} )
          p["content"].each do |c|
             total_views += c["views"].to_i
             path = c["path"].split("/")
             if path.length > 2
               if path[1] == "books"
                 isbn = path[2]
                 if summary.has_key?(isbn)
                    summary[isbn] += c["views"].to_i 
                 else
                   summary[isbn] = c["views"].to_i 
                 end
                 total_book_views += c["views"].to_i
               end
             end
          end
        end 
        out = {
          :date => date,
          :total_views => total_views,
          :total_book_views => total_book_views,
          :books => summary
        }
        @redis.set("chimera:#{date}", out)        
     rescue Exception => e
        log(@logger, @queue, process_id, "The following error occurred: #{e} \n #{e.backtrace}")
        raise e
     end
     log(@logger, @queue, process_id, "Gauge data saved in redis db for 1 hour")     
  end

end
