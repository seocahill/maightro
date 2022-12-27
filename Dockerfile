from ruby:alpine

workdir /app

run \
  apk --update add build-base  && \
  gem install sinatra terminal-table activemodel thin

copy . ./

env RACK_ENV=production
env PORT="8080"

expose 8080

cmd ["ruby", "maightro.rb"]