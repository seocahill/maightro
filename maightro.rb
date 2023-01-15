# frozen_string_literal: true

require 'sinatra'
require 'sentry-ruby'
require 'date'

# catch bugs
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:sentry_logger, :http_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    0.5
  end
end

helpers do
  def current_page_css(path)
    if request.path == path
      "bg-gray-900 text-white px-3 py-2 rounded-md text-sm font-medium"
    else
      "text-gray-300 hover:bg-gray-700 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
    end
  end
end

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

get '/analysis' do
  @scenario = params["scenario"] || "Option1"
  @results = Module.const_get(@scenario).new.run_analysis
  # @results = Option1.new.run_analysis
  erb :analysis, layout: false
end

get '/history' do
  erb :history
end

get '/about' do
  erb :about
end

get '/code' do
  @results = Option1.new.run_analysis
  erb :code
end

get '/test-sentry' do
  Sentry.capture_message("test message")
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
