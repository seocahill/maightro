# frozen_string_literal: true

require 'sinatra'
# require 'pry'
require 'date'

# pull in the helpers and controllers
Dir.glob('./models/**/*.rb').each { |file| require file }

get '/' do
  @options = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]
  @timetables = []
  @default_date = Date.today.strftime "%Y-%m-%d"
  # @default_scenario = "Option1"
  @to = "Westport"
  @from = "Ballina"
  erb :index
end

get '/info' do
  @scenario = params["scenario"].downcase
  erb :info, layout: false
end

post '/timetable' do
  @options = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]
  @timetables = []
  @to = params["to"]
  @from = params["from"]
  @default_date = params['date']
  @default_scenario = params["scenario"]

  @timetables = if params["scenario"]
                  date = params["date"].split('-').join
                  [Module.const_get(params["scenario"]).new(date, params["from"], params["to"]).rows]
                else
                  []
                end
  erb :results, layout: false
end
