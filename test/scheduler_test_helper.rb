# frozen_string_literal: true

require "test/unit"
require "date"

# Try to load VCR, but don't fail if it's not available
VCR_AVAILABLE = begin
  require "vcr"
  require "webmock"

  VCR.configure do |c|
    c.hook_into :webmock
    c.cassette_library_dir = "test/fixtures/vcr_cassettes"
    c.default_cassette_options = {
      match_requests_on: [:method, :host, :path]
    }
    c.ignore_request do |request|
      request.headers["X-Vcr-Bypass"] == ["true"]
    end
  end

  true
rescue LoadError
  false
end

require_relative "../lib/maightro"
require_relative "../lib/maightro/schedulers"

module SchedulerTestHelpers
  def last_thursday
    today = Date.today
    last_thursday = today - ((today.wday - 4) % 7)
    last_thursday.strftime("%Y%m%d")
  end

  def last_sunday(date = Date.today)
    sunday = date - ((date.wday + 1) % 7)
    sunday.strftime("%Y%m%d")
  end

  # Helper to get rows from a timetable for backwards compatibility
  def get_rows(scheduler_class, date, from, to)
    scheduler = scheduler_class.new(date: date)
    timetable = scheduler.run
    timetable.rows(from, to)
  end

  # Helper to run analysis
  def run_analysis(scheduler_class, date = last_thursday)
    scheduler = scheduler_class.new(date: date)
    timetable = scheduler.run
    analyzer = Maightro::Services::TimetableAnalyzer.new(all_rows(timetable))
    analyzer.run_analysis
  end

  # Get all possible rows from timetable (for analysis)
  def all_rows(timetable)
    stations = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]
    rows = []
    stations.each do |from|
      stations.each do |to|
        next if from == to

        rows.concat(timetable.rows(from, to))
      end
    end
    rows
  end

  def distance_in_mins(dep_str, arr_str)
    arr_time = Time.parse(arr_str)
    dep_time = Time.parse(dep_str)
    arr_time += 86_400 if arr_time < Time.parse("05:00")
    dep_time += 86_400 if dep_time < Time.parse("05:00")
    (arr_time - dep_time).fdiv(60)
  end

  # Skip test if VCR is not available
  def skip_without_vcr
    omit("VCR not available") unless VCR_AVAILABLE
  end
end
