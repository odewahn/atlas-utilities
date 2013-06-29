require 'httparty'
require 'open-uri'
require 'json'

class ChimeraEndpoint
  include HTTParty
#  debug_output $stderr
  base_uri ENV["CHIMERA_URL"]
  default_params :auth_token => ENV["CHIMERA_AUTH_TOKEN"]
  format :json

  class << self
    
    
    def create_user(email, name)
      post("/api/users", {:body => {:user => {:name => name, :email => email}}})
    end

    def get_book(isbn)
      get("/api/books/#{isbn}.json")
    end

    def get_book_permissions_by_isbn(isbn)
      get_book_permissions({:book => {:isbn => isbn}})
    end

    def get_book_permissions(params)
      get("/api/book_permissions.json", :query => params)
    end

    def create_book_permission(phash)
      phash["book_format"] = "all"
      post("/api/book_permissions.json", {:body => {:book_permission => phash}})
    end

    def delete_book_permission(phash)
      delete("/api/book_permissions/#{phash["id"]}.json")
    end
    
    

  end

end
