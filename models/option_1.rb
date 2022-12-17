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

# class Option1
  include Helper

  results = JourneyPlanner.new.search

  timetable = []

  results.trains_out.each do |trip|
    trip['secL'].each do |train|
      timetable << TrainPath.create(train, trip, results.stations)
    end
  end

  results.trains_ret.each do |trip|
    trip['secL'].each do |train|
      timetable << TrainPath.create(train, trip, results.stations)
    end
  end

  rows = timetable
    .group_by(&:trip_id)
    .map  { |g,t| [t.first.from, t.last.to, t.first.dep.strftime("%H:%M"), t.last.arr.strftime("%H:%M"), (t.last.arr - t.first.dep).fdiv(60).round] }
    .sort_by { |t| t[2] }
  headers = %w[from to dep arr dur]
  puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }
# end

