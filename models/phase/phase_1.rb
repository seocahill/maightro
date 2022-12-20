#! /usr/bin/ruby
# frozen_string_literal: true

# Naive Algorithm:
# - Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
# - BMT duration is 27.  Minimum dwell is 3 minutes.
# - For each WT at MJ
#   - Check direction of train
#   - Add  BT dep/arr times to hash table for appropriate dir of travel
#   - Ignore scheduling clashes for now (e.g self or freight paths)
#   - 2 blocks WM, BM.

require 'uri'
require 'json'
require 'net/http'
require 'pry'

require 'time'
require 'terminal-table'
require_relative 'option_1'

manulla_times = Option1.new.train_trips
ballina_trains = []

# TrainPath = Struct.new(:arr, :dep, :dir, :station, :from)

# manulla_times.each do |wt|
#   manulla = wt.arr || wt.dep
#   transfer_time = manulla[0..3].insert(2, ':')

#   from = Time.parse(transfer_time) - (27 * 60)
#   ballina_trains << TrainPath.new('Ballina-Manulla', "to #{wt.dir}", from.strftime('%H:%M'), transfer_time, nil)

#   depart_time = Time.parse(transfer_time) + 120
#   to = depart_time + (27 * 60)
#   connection = wt.dir == 'Westport' ? 'Dublin Heuston' : 'Westport'
#   ballina_trains << TrainPath.new('Manulla-Ballina', "from #{connection}", depart_time.strftime('%H:%M'),
#                                   to.strftime('%H:%M'), nil)
# end

# rows = ballina_trains.sort_by(&:dep)
# [nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
#   next if prev.nil?

#   padding = (Time.parse(cur.dep) - Time.parse(prev.arr)).fdiv(60).round
#   cur.station = padding
# end
rows = manulla_times.map(&:values)
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
