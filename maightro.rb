# frozen_string_literal: true

require 'sinatra'
# require 'pry'
require 'date'

# pull in the helpers and controllers
Dir.glob('./models/**/*.rb').each { |file| require file }

get '/' do
  @timetables = []
  @default_date = Date.today.strftime "%Y-%m-%d"
  @default_scenario = "Option1"
  erb :index
end

post '/timetable' do
  @timetables = []
  @default_date = params['date']
  @default_scenario = params["scenario"]

  @timetables = if params["scenario"]
                  date = params["date"].split('-').join
                  [Module.const_get(params["scenario"]).new(date).rows]
                else
                  []
                end
  erb :results
end


