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

local_idx = 0

westport_trains.each do |wt|
  from = wt.dep - (29 * 60) # 27 min + 2 dwell/transfer
  ballina_trains << TrainPath.new(from: 'Ballina', to: "Manulla", dep: from, arr: wt.dep, trip_id: wt.trip_id)

  depart_time = wt.dep
  arr_time = depart_time + (27 * 60)
  # trip id is nil here because this train is connection from Dublin, not Maightro
  ballina_trains << TrainPath.new(from: 'Manulla', to: "Ballina", dep: depart_time, arr: arr_time, trip_id: "L-#{local_idx}")
  local_idx +=1
end

dub_trains.each do |dt|
  from = dt.arr - (29 * 60) # 27 min + 2 dwell/transfer
  # trip id is nil here because this train is connection to Dublin, not Maightro
  ballina_trains << TrainPath.new(from: 'Ballina', to: "Manulla", dep: from, arr: dt.arr, trip_id: "L-#{local_idx}")
  local_idx +=1

  depart_time = dt.arr
  arr_time = depart_time + (27 * 60)
  ballina_trains << TrainPath.new(from: 'Manulla', to: "Ballina", dep: depart_time, arr: arr_time, trip_id:  dt.trip_id)
end



rows = (ballina_trains + westport_trains + dub_trains)
          .group_by(&:trip_id)
          .map do |g,t|
            if t.length == 2 && t.first.trip_id.include?("C-")
              bt, wt = t
              [bt.from, wt.to, bt.dep.strftime("%H:%M"), wt.arr.strftime("%H:%M"), (wt.arr - bt.dep).fdiv(60).round, bt.trip_id]
            elsif t.length == 2 && t.first.trip_id.include?("R-")
              bt, dt = t
              [dt.from, bt.to, dt.dep.strftime("%H:%M"), bt.arr.strftime("%H:%M"), (bt.arr - dt.dep).fdiv(60).round, dt.trip_id]
            else
              [t.first.from, t.first.to, t.first.dep.strftime("%H:%M"), t.first.arr.strftime("%H:%M"), (t.first.arr - t.first.dep).fdiv(60).round, t.first.trip_id]
            end
          end.compact.sort_by { |t| t[2] }

headers = %w[path connection dep arr duration trip_id dwell info]
tt_rows = rows.reject { |t| t[5].include?("L-") }

# check for clashes and adjust tt to fix
tt_rows[0][6] = 0 # first train has no dwell
tt_rows.each_cons(2) do |current, nxt|
  overlap = (Time.parse(current[3]) - Time.parse(nxt[2]))
  if overlap > 0
    nxt[2] = (Time.parse(nxt[2]) + overlap + 180).strftime("%H:%M")
    nxt[3] = (Time.parse(nxt[3]) + overlap).strftime("%H:%M")
    nxt[7] = "advanced by #{overlap.fdiv(60)} mins to avoid clash"
    overlap = (Time.parse(current[3]) - Time.parse(nxt[2]))
  end
  nxt[6] = overlap.fdiv(60).abs
end
puts Terminal::Table.new rows: tt_rows, headings: headers, title: 'An Maightró', style: { all_separators: true }