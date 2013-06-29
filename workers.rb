require "./endpoints"


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

