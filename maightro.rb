# frozen_string_literal: true

require 'sinatra'
require 'pry'

# pull in the helpers and controllers
Dir.glob('./models/**/*.rb').each { |file| require file }

get '/' do
  @timetables = []
  puts params.inspect
  @timetables = if params["scenario"]
                  [Module.const_get(params["scenario"]).new.rows]
                else
                  []
                end
  erb :index
end


