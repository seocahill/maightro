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
trains_out = JSON.parse(response.body).dig('svcResL', 0, 'res', 'outConL')
trains_ret = JSON.parse(response.body).dig('svcResL', 0, 'res', 'retConL')

timetable = []

trains_out.each do |train|
  train['secL'].each do |line|
    line.dig('jny', 'stopL').map do |trip|
      timetable << TrainPath.new(
        dir: trip['dDirTxt'],
        arr: parse_time(trip['aTimeS']),
        dep: parse_time(trip['dTimeS']),
        station: trip['locX'],
        from: 'Ballina'
      )
    end
  end
end

trains_ret.each do |train|
  train['secL'].each do |line|
    line.dig('jny', 'stopL').map do |trip|
      timetable << TrainPath.new(
        dir: trip['dDirTxt'],
        arr: parse_time(trip['aTimeS']),
        dep: parse_time(trip['dTimeS']),
        station: trip['locX'],
        from: 'Westport'
      )
    end
  end
end

manulla_times = timetable.flatten.select do |t|
  t.station == 1
end.reject { |t| t.dir == 'Ballina' }.reject { |t| t.dir == 'Manulla Junction' }
rows = manulla_times.sort_by { |t| t.from }.map(&:values)
headers = %w[path connection dep arr dwell]
puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }

