require 'uri'
require 'redis'
require 'json'
require 'dotenv'

Dotenv.load

puts ENV["REDIS_URL"]


uri = URI.parse(ENV["REDIS_URL"])
@redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

date = "2013-07-05"

total_views = 0
total_book_views = 0
summary = {}
@redis.smembers("chimera:#{date}:pages").each do |key|
  p = eval(@redis.get(key))
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
puts JSON.pretty_generate(out)
  