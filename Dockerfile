from ruby:alpine

workdir /app

run \
  apk --update add build-base  && \
  gem install sinatra terminal-table activemodel thin

copy . ./

cmd ["ruby", "maightro.rb"]