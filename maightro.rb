require 'sinatra'
require 'pry'

get '/' do
  @timetables = []
  if params[:date]
    @timetables = generate_timetables(params)
  else
    @timetables = []
  end
  erb :index
end

# post '/timetable' do
#    params
# # => {"date"=>"2022-12-16", "push-notifications"=>"on"}
#   generate_timetables(params)
# end