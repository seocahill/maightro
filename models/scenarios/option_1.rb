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

class Option1
  include Helper

  attr_reader :results, :train_trips

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport')
    @results = JourneyPlanner.new.search(date, from, to)
    @train_trips = list_train_trips
  end

  def list_train_trips
    [].tap do |trips|
      stations = @results.stations
      @results.trains_out.each do |trip|
        trip['secL'].each do |train|
          trips << TrainPath.create(train, trip, stations)
        end
      end

      @results.trains_ret.each do |trip|
        trip['secL'].each do |train|
          trips << TrainPath.create(train, trip, stations)
        end
      end
    end
  end

  def rows
    rows = @train_trips
           .group_by(&:trip_id)
           .map do |_g, t|
             [t.first.from, t.last.to, t.first.dep.strftime('%H:%M'), t.last.arr.strftime('%H:%M'),
              (t.last.arr - t.first.dep).fdiv(60).round]
           end
           .sort_by { |t| t[0] }
    rows
  end

  def as_ascii
    headers = %w[from to dep arr dur]
    puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }
  end
end

Option1.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
