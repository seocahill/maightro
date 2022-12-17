# frozen_string_literal: true

require 'sinatra'
require 'pry'

get '/' do
  @timetables = []
  @timetables = if params[:date]
                  generate_timetables(params)
                else
                  []
                end
  erb :index
end

# post '/timetable' do
#    params
# # => {"date"=>"2022-12-16", "push-notifications"=>"on"}
#   generate_timetables(params)
# end
