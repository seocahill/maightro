# frozen_string_literal: true

require 'sinatra'
require 'pry'

# pull in the helpers and controllers
Dir.glob('./models/**/*.rb').each { |file| require file }

get '/' do
  @scenarios = %[option_1 option_1a option_2 option_3 option_3b]
  @timetables = []
  @timetables = if params[:option]
                  [Module.const_get(params[:option]).new.rows]
                else
                  []
                end
  erb :index
end


