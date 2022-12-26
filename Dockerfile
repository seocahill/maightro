from ruby:alpine

workdir /app

run \
  apk --update add build-base  && \
  gem install sinatra terminal-table activemodel thin

copy . ./

env RACK_ENV=production

expose 4567

cmd ["ruby", "maightro.rb"]