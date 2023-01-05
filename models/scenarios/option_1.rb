#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo

require 'json'
# require 'pry'
require 'time'
require 'terminal-table'
require_relative 'base_option'

class Option1 < BaseOption

  attr_reader :results, :train_trips

  def exec_option
    @results = JourneyPlanner.new.search(@date, @from, @to)
    @routes, _stops = find_route(@from, @to)
    @train_trips = list_train_trips
  end

  def list_train_trips
    [].tap do |trains|
      @results.trains_out.each do |trip|
        add_trains(trains, trip)
      end

      @results.trains_ret.each do |trip|
        add_trains(trains, trip)
      end
    end
  end

  def add_trains(trains, trip)
    trip['secL'].each do |train|
      train = TrainPath.create(train, trip, @results.stations)
      @routes.each { |route| train.send("#{route}_id=", train.trip_id) }
      trains << train
    end
  end
end

Option1.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
