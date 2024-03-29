require 'date'
require 'test/unit'
require 'vcr'
require 'pry'
require 'pry-byebug'

VCR.configure do |c|
  c.hook_into :webmock
  c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  c.default_cassette_options = {
    :match_requests_on => [:method, :host, :path]
  }
  c.ignore_request do |request|
    request.headers["X-Vcr-Bypass"] == ['true']
  end
end

module TestHelpers
  def last_thursday
    today = Date.today
    # Subtracting days from today until we get a Thursday (where day of the week is 4)
    last_thursday = today - ((today.wday - 4) % 7)
    last_thursday.strftime('%Y%m%d')
  end

  def last_sunday(date = Date.today)
    sunday = date - ((date.wday + 1) % 7)
    sunday.strftime('%Y%m%d')
  end
end
