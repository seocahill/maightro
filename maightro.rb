# frozen_string_literal: true

require 'sinatra'
require 'pry'
require 'date'

# pull in the helpers and controllers
Dir.glob('./models/**/*.rb').each { |file| require file }

get '/' do
  @timetables = []
  @default_date = Date.today.strftime "%Y-%m-%d"
  @timetables = if params["scenario"]
                  date = params["date"].split('-').join
                  [Module.const_get(params["scenario"]).new(date, params["sort"]).rows]
                else
                  []
                end
  erb :index
end


