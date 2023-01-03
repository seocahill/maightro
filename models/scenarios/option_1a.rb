#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo improved!
# Naive Algorithm:
# - Find and fix useless trains
# - Check if Ballina train can be inserted
# - If that doesn't work alter Westport making sure path is available (todo)
# - BMT duration is 27.  Minimum dwell is 3 minutes.

## TODO
# - standardize time lookup
# - refactor
# - would be nice to check if train can be reschudled i.e
# - get all trains on port - wes for window and see if can be crossed at station, adjust.

require 'uri'
require 'json'
require 'net/http'
# require 'pry'

require 'time'
require 'terminal-table'
require_relative 'base_option'
require_relative 'option_1'

class Option1a < BaseOption
  include Helper

  def exec_option
    @train_trips = schedule_train_trips
    fix_overlapping_trains # DEBUG
  end

  def schedule_train_trips
    ic_trips = Option1.new(@date, "Ballyhaunis", "Westport").train_trips
    ballina_trains = []

    # covey trains already grouped
    dir_westport_trains = ic_trips.flatten.select { |t| t.info == 'to Westport' }
    dir_dub_trains = ic_trips.flatten.select { |t| t.info == 'to Dublin Heuston' }
    branch_trip_time = duration('Ballina', 'Manulla Junction')

    dir_dub_trains.each do |ic|
      dep_ballina = ic.time_at_junction - branch_trip_time - @dwell
      # group costello
      stops = stops('Ballina', 'Manulla Junction', dep_ballina)
      ballina_trains << TrainPath.new(from: 'Ballina', to: 'Manulla Junction', dep: dep_ballina, arr: ic.dep, costello_id: ic.trip_id, stops: stops)

      arr_time = ic.time_at_junction + branch_trip_time
      # group nephin
      stops = stops('Manulla Junction', 'Ballina', ic.time_at_junction)
      ballina_trains << TrainPath.new(from: 'Manulla Junction', to: 'Ballina', dep: ic.time_at_junction, arr: arr_time,
                                      nephin_id: ic.trip_id, stops: stops)
    end

    dir_westport_trains.each do |ic|
      # all routes!
      dep_ballina = ic.time_at_junction - branch_trip_time - @dwell
      # group nephin
      stops = stops('Ballina', 'Manulla Junction', dep_ballina)
      # binding.pry
      ballina_trains << TrainPath.new(from: 'Ballina', to: 'Manulla Junction', dep: dep_ballina, arr: ic.dep, nephin_id: ic.trip_id, stops: stops)

      arr_time = ic.time_at_junction + branch_trip_time
      # group costello
      stops = stops('Manulla Junction', 'Ballina', ic.time_at_junction)
      ballina_trains << TrainPath.new(from: 'Manulla Junction', to: 'Ballina', dep: ic.time_at_junction, arr: arr_time,
                                      costello_id: ic.trip_id, stops: stops)
    end

    ballina_trains + dir_westport_trains + dir_dub_trains
  end

  def fix_overlapping_trains
    # TODO: when changing check path exists on Dublin - Westport.
    sorted_nephin_trains = @train_trips.reject {|t| t.nephin_id.nil? }.group_by(&:nephin_id).sort_by {|trip_id, trains| trains.map(&:dep).min }
    sorted_nephin_trains.each_cons(2) do |current, nxt|
      current_train_arr = current[1].flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.max { |a,b| a[1] <=> b[1] }.dig(1)
      next_train_dep = nxt[1].flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.min { |a,b| a[1] <=> b[1] }.dig(1)
      overlap = current_train_arr - next_train_dep
      if overlap.positive?
        adjustment = overlap + @turnaround
        nxt[1].each do |train|
          train.dep += adjustment
          train.arr += adjustment
          train.stops.each { |stop| stop[1] += adjustment }
          train.info = "advanced by #{adjustment.fdiv(60)} mins to avoid clash"
        end
      end
    end
  end
end

Option1a.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
