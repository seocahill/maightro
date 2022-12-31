#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo

require 'json'
# require 'pry'
require 'time'
require 'terminal-table'
require_relative '../helper'
require_relative '../journey_planner'
require_relative '../train_path'

class BaseOption
  include Helper

=begin
  # structure
  "secL"=>
   [{"type"=>"JNY",
     "jny"=>
      {
       "stopL"=>
        [{"locX"=>0, "dTimeS"=>"093500", "dDirTxt"=>"Manulla Junction"},
         {"locX"=>2, "aTimeS"=>"094600",  "dTimeS"=>"094600"},
         {"locX"=>1, "aTimeS"=>"100200", "aProgType"=>"PROGNOSED"}],
=end
  def initialize
    @stop_info = YAML.load(File.read("config.yaml"))
    @turnaround = 180.0 # min 3 minutes to reverse direction
    @dwell = 60.0 # max of arr - dep when present
  end

  def generate_configuration
    date = Time.now.strftime "%Y%m%d"

    # nephin
    nephin_line = JourneyPlanner.new.search(date, "Ballina", "Westport")
    nephin_line.trains_out.each do |trip|
      extract_trip_durations(trip, nephin_line.stations)
    end
    nephin_line.trains_ret.each do |trip|
      extract_trip_durations(trip, nephin_line.stations)
    end

    # covey
    covey_line = JourneyPlanner.new.search(date, "Westport", "Claremorris")
    covey_line.trains_out.each do |trip|
      extract_trip_durations(trip, covey_line.stations)
    end
    covey_line.trains_ret.each do |trip|
      extract_trip_durations(trip, covey_line.stations)
    end

    # write config
    File.open('config.yaml', 'w') do |file|
      file.write(@stop_info.to_h.to_yaml)
    end
  end

  private

  def extract_trip_durations(trip, stations)
    trip.dig('secL').each do |t|
      t.dig('jny', 'stopL').each_cons(2) do |start, finish|
        next unless  finish['aTimeS'] && start["dTimeS"]

        dur = parse_time(finish['aTimeS']) - parse_time(start["dTimeS"])
        if start['aTimeS'] && start["dTimeS"]
          puts parse_time(start["dTimeS"]) - parse_time(start['aTimeS']) # dwell
        end
        x = @stop_info[find_station(start, stations)] ||= {}
        y = x[find_station(finish, stations)] ||= nil
        x[find_station(finish, stations)] = dur if (y.nil? || dur < y)
      end
    end
  end
end

BaseOption.new.generate_configuration if __FILE__ == $PROGRAM_NAME
