from ruby:alpine

workdir /app

COPY Gemfile* ./

run \
  apk --update add build-base && \
  bundle install

copy . ./

env RACK_ENV=production
env PORT=8080

expose 8080

CMD ["bundle", "exec", "rackup", "-p", "$PORT"]