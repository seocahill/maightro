# frozen_string_literal: true

require 'date'
require 'uri'
require 'cgi'

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

  def svc_change(baseline, cell)
    percent = (cell - baseline).fdiv(baseline).*(100).round
    return "-" if percent.zero?

    "(#{percent}%)"
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
  if @scenario !=  "Option1"
    @baseline = Option1.new.run_analysis
  end
  @results = Module.const_get(@scenario).new.run_analysis
  # @results = Option1.new.run_analysis
  erb :analysis, layout: false
end

get '/book' do
  url = URI("https://journeyplanner.irishrail.ie/webapp/")
  date = Date.parse(params["date"]).strftime("%d/%m/%Y")
  query = URI.encode_www_form({
    "start": "1&REQ0JourneyStopsS0G",
    "REQ0JourneyStopsS0G": params["from"],
    "REQ0JourneyStopsZ0G": params["to"],
    "journey_mode": "single",
    "REQ0JourneyDate": "#{date}",
    "REQ0JourneyTime": "allday",
    "Number_adults": "1",
    "language": "en_IE"
  })
  url.query = query

  redirect url
end

get '/history' do
  erb :history
end

get '/ask' do
  redirect "https://www.oireachtas.ie/en/members/tds/?tab=constituency&constituency=%2Fie%2Foireachtas%2Fhouse%2Fdail%2F33%2Fconstituency%2FMayo"
end

get '/about' do
  erb :about
end

get '/code' do
  @results = Option1.new.run_analysis
  erb :code
end

before do
  headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  headers['Access-Control-Allow-Origin'] = '*'
  headers['Access-Control-Allow-Headers'] = 'Accept, Authorization, Origin, HX-Boosted, HX-Current-URL, HX-History-Restore-Request, HX-Prompt, HX-Request, HX-Target, HX-Trigger-Name, HX-Trigger'
end

options '*' do
  response.headers['Allow'] = 'HEAD, GET, PUT, DELETE, OPTIONS, POST'
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, HX-Boosted, HX-Current-URL, HX-History-Restore-Request, HX-Prompt, HX-Request, HX-Target, HX-Trigger-Name, HX-Trigger'
end

post '/timetable' do
  @booking_url = booking_url(params)
  @options = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]
  @timetables = []
  @to = params["to"]
  @from = params["from"]
  @default_date = params['date']
  @booking_date = CGI.escape(params['date'].gsub("-", "/"))
  @default_scenario = params["scenario"]

  @timetables = if params["scenario"]
                  date = params["date"].split('-').join
                  [Module.const_get(params["scenario"]).new(date, params["from"], params["to"]).rows]
                else
                  []
                end
  erb :results, layout: false
end

private_methods

def booking_url(params)
    url = URI("https://journeyplanner.irishrail.ie/webapp/")
    date = Date.parse(params["date"]).strftime("%d/%m/%Y")
    query = URI.encode_www_form({
      "start": "1&REQ0JourneyStopsS0G",
      "REQ0JourneyStopsS0G": params["from"],
      "REQ0JourneyStopsZ0G": params["to"],
      "journey_mode": "single",
      "REQ0JourneyDate": "#{date}",
      "REQ0JourneyTime": "allday",
      "Number_adults": "1",
      "language": "en_IE"
    })
    url.query = query
    url
  end
