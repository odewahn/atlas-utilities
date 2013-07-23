web: rackup config.ru -p $PORT
worker: TERM_CHILD=1 env QUEUE=* bundle exec rake resque:work