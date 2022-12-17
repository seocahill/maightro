#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo

require 'json'
require 'pry'

require 'time'
require 'terminal-table'
require_relative 'helper'
require_relative 'journey_planner'
require_relative 'train_path'

include Helper

response = JourneyPlanner.new.search
stations = JSON.parse(response.body).dig('svcResL', 0, 'res', 'common', 'locL')
trains_out = JSON.parse(response.body).dig('svcResL', 0, 'res', 'outConL')
trains_ret = JSON.parse(response.body).dig('svcResL', 0, 'res', 'retConL')

timetable = []

trains_out.each do |trip|
  trip['secL'].each do |train|
    timetable << TrainPath.new(
      from: find_station(train['dep'], stations),
      to: find_station(train['arr'], stations),
      arr: parse_time(train['arr']['aTimeS']),
      dep: parse_time(train['dep']['dTimeS']),
      info:  "to " + train['jny']['dirTxt'],
      group: trip['cid']
    )
  end
end

trains_ret.each do |trip|
  trip['secL'].each do |train|
    timetable << TrainPath.new(
      from: find_station(train['dep'], stations),
      to: find_station(train['arr'], stations),
      arr: parse_time(train['arr']['aTimeS']),
      dep: parse_time(train['dep']['dTimeS']),
      info: "to " + train['jny']['dirTxt'],
      group: trip['cid']
    )
  end
end

rows = timetable
  .group_by(&:group)
  .map  { |g,t| [t.first.from, t.last.to, t.first.dep.strftime("%H:%M"), t.last.arr.strftime("%H:%M"), (t.last.arr - t.first.dep).fdiv(60).round] }
  .sort_by { |t| t[2] }
headers = %w[from to dep arr dur]
puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }

