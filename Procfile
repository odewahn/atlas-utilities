web: rackup config.ru -p $PORT
worker: env QUEUE=* bundle exec rake resque:work --trace