#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo improved!
# Naive Algorithm:
# - Find and fix useless trains
# - Check if Ballina train can be inserted
# - If that doesn't wor alter Westport making sure path is available.
# - BMT duration is 27.  Minimum dwell is 3 minutes.

require 'uri'
require 'json'
require 'net/http'
require 'pry'

require 'time'
require 'terminal-table'
require_relative 'option_1'


all_trips = Option1.new.train_trips
bad_trips = all_trips.group_by(&:trip_id).select { |g,t| (t.last.arr - t.first.dep).fdiv(60) > 55 }
ballina_trains = []

westport_trains = all_trips.flatten.select { |t| t.info == "to Westport" }
dub_trains = all_trips.flatten.select { |t| t.info == "to Dublin Heuston" }

westport_trains.each do |wt|
  from = wt.dep - (30 * 60) # 27 min + 3 dwell/transfer
  ballina_trains << TrainPath.new(from: 'Ballina', to: "Manulla", dep: from, arr: wt.dep, trip_id: wt.trip_id)

  depart_time = wt.dep
  arr_time = depart_time + (27 * 60)
  # trip id is nil here because this train is connection from Dublin, not Maightro
  ballina_trains << TrainPath.new(from: 'Manulla', to: "Ballina", dep: depart_time, arr: arr_time, trip_id: nil)
end

dub_trains.each do |dt|
  from = dt.dep - (30 * 60) # 27 min + 3 dwell/transfer
  # trip id is nil here because this train is connection to Dublin, not Maightro
  ballina_trains << TrainPath.new(from: 'Ballina', to: "Manulla", dep: from, arr: dt.dep, trip_id: nil)

  depart_time = dt.dep
  arr_time = depart_time + (27 * 60)
  ballina_trains << TrainPath.new(from: 'Manulla', to: "Ballina", dep: depart_time, arr: arr_time, trip_id:  dt.trip_id)
end

rows = (ballina_trains + westport_trains + dub_trains).map(&:values)
headers = %w[path connection dep arr dwell]
puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }

# ba = ballina_trains.select { |t| t.from == 'Ballina-Manulla' }
# bam = ba.each_cons(2).map do |a, b|
#   Time.parse(b.dep) - Time.parse(a.dep)
# end.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
# bad = ba.map { |t| Time.parse(t.dep) - Time.parse(t.arr) }.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
# wp = ballina_trains.reject { |t| t.from == 'Ballina-Manulla' }
# wpm = wp.each_cons(2).map do |a, b|
#   Time.parse(b.dep) - Time.parse(a.dep)
# end.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
# wpd = wp.map { |t| Time.parse(t.dep) - Time.parse(t.arr) }.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
# free_paths = ballina_trains.select { |t| t.station.to_i > 30 }.count
# short_turnarounds = ballina_trains.select { |t| t.station.to_i < 5 }.select { |t| t.from == 'Ballina-Manulla' }.count
# puts '=' * 99
# puts "#{ba.count} Trains each way, with an averge service gap of #{bam},  #{free_paths} free paths during service hours and #{short_turnarounds} quick turnarounds in Ballina."
# puts '=' * 99
# Calculate Ballina <> Manulla trains
# Simple conclusion is that Dublin - Wesport arr at Manulla at  10:06  needs to be delayed by 30 mins.

# binding.pry
# puts response.read_body
