#! /usr/bin/ruby
# frozen_string_literal: true

# Direct Algorithm:
# - Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
# - In this simulation no freight paths are considered. Variables like staff, fuel etc are assumed to be sufficient.
# - BMT duration is 27.  Minimum dwell is 3 minutes. WMT duration is 19 mins.
# - Loop from start to end time creating local or connecting trains depending on path availability
# - If full bal-wes is possible before next connection do it
# - If next connection is from Ballina and must return to Ballina with down Dublin passengers, see if local train can run to Westport or Castlebar instead of just waiting.
# Fixme: Train times overlap, shouldn't be possible

require 'uri'
require 'json'
require 'net/http'
# require 'pry'
# require 'pry-byebug'
# require 'pry-rescue'
# require 'pry-stack_explorer'

require 'time'
require 'terminal-table'
require_relative '../journey_planner'
require_relative 'option_2'

# option 1 start from middle
# start from Ballina, morning train. Finish in Ballina last connection to Westport.
# make sure each Dublin-Wesport train is connected to:
# for each connection, depending on direction, create a BW or WB train connecting WDW mainline train.
# Gaps if gap exists > 2 trips insert extra train e.g (27 + 19 + 3) * 2 = 98 mins.

# option two linear with decision at end of each block
# or starting from first train
# go up to meet westport
# continue to westport
# check which way next meetup is
# calculate if possible to make another roundtrip, if so do it
# if not wait and then travel up to make connection
# remember bal-fox and wes-cas can be useful trips in and of themselves also

# try 2 fallback to 1

class Option3 < BaseOption
  def exec_option
    @min_dwell = 180
    @bal_block = 27 * 60
    @wes_block = 19 * 60
    @man_cas_block = 6 * 60
    @one_day = 24 * 3600
    @full_trip = @bal_block + @min_dwell + @wes_block

    @cla_block = 14 * 60
    @claremorris_trains = []
    @trip_id_idx = 0
    schedule_trains
  end

  #### Claremorris

  def train_in_wrong_position(connecting_train, current_position)
    if connecting_train.from == 'Ballina' && current_position == 'Westport'
      false
    elsif connecting_train.from == 'Westport' && current_position == 'Claremorris'
      false
    elsif connecting_train.from == 'Castlebar' && current_position == 'Claremorris'
      false
    else
      true
    end
  end

  # Add claremorris local trains

  def schedule_trains
    @trains = Option2.new(@date).train_trips

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')
    current_position = 'Claremorris'
    # the ballina castlebar trains are extended connectors ignore them
    @connecting_trains = @trains.select { |t| [%w[Ballina Westport]].include? [t.from, t.to].sort }

    until arr_time > Time.parse('23:59')
      # get next 2 connects
      if connecting_train = @connecting_trains.first
        trip_id = "LCY-#{@trip_id_idx}"
        # Need to check here if the local Clare train is in correct position e.g:
        # If meeting ex Ballina needs to be in Westport
        # If meeting ex Westport needs to be in Claremorris
        # if connecting_train&.trip_id =~ /^(C|R)-[0-9]$/
        #   @connecting_trains.delete connecting_train
        if train_in_wrong_position(connecting_train, current_position)

          train = if current_position == 'Claremorris'
                    # no dwell in manulla
                    arr_time = dep_time + duration("Claremorris", "Westport")
                    stops = stops("Claremorris", "'Westport", dep_time)
                    TrainPath.new(from: 'Claremorris', to: 'Westport', info: 'local', dep: dep_time,
                                  arr: arr_time, position: 'Westport', trip_id: trip_id, covey_return_id: trip_id, stops: stops)
                  else
                    arr_time = dep_time + duration("Westport", "Claremorris")
                    stops = stops("Westport", "Claremorris", dep_time)
                    TrainPath.new(from: 'Westport', to: 'Claremorris', info: 'local', dep: dep_time,
                                  arr: arr_time, position: 'Claremorris', trip_id: trip_id, covey_id: trip_id, stops: stops)
                  end
          @claremorris_trains << train
        else

          # create train to meet connect
          train = if current_position == 'Claremorris'
                    dep_time = connecting_train.time_at_junction - duration("Claremorris", "Manulla Junction")
                    arr_time = dep_time + @dwell + duration("Manulla Junction", "Westport")
                    stops = stops("Claremorris", "Westport", dep_time)
                    TrainPath.new(from: 'Claremorris', to: 'Westport', dep: dep_time, arr: arr_time, trip_id: connecting_train.trip_id, stops: stops, covey_return_id: trip_id)
                  else
                    dep_time = connecting_train.time_at_junction - duration("Westport", "Manulla Junction")
                    arr_time = dep_time + @dwell + duration("Manulla Junction", "Claremorris")
                    stops = stops("Westport", "Claremorris", dep_time)
                    TrainPath.new(from: 'Westport', to: 'Claremorris', dep: dep_time, arr: arr_time, trip_id: connecting_train.trip_id, stops: stops, covey_id: trip_id)
                  end

          # from: uptrain origin, to: connecting train destination
          find_route(train.from, connecting_train.stops.last[0]).dig(0).each do |route|
            train.send("#{route}_id=", trip_id)
            connecting_train.send("#{route}_id=", trip_id)
          end
          # from: connecting train origin, to: downtrain destination
          find_route(connecting_train.stops.first[0], train.to).dig(0).each do |route|
            train.send("#{route}_id=", trip_id)
            connecting_train.send("#{route}_id=", trip_id)
          end
          @claremorris_trains << train
          # and pop off connecting trains queue
          @connecting_trains.delete connecting_train
        end
      else
        # just make local train
        local_train = if current_position == 'Claremorris'
                        # no dwell in manulla
                        stops = stops("Claremorris", "Westport", dep_time)
                        arr_time = dep_time + duration("Claremorris", "Westport")
                        TrainPath.new(from: 'Claremorris', to: 'Westport', dir: 'local', dep: dep_time,
                                      arr: arr_time, position: 'Westport', trip_id: trip_id, covey_return_id: trip_id, stops: stops)
                      else
                        stops = stops("Westport", "Claremorris", dep_time)
                        arr_time = dep_time + duration("Westport", "Claremorris")
                        TrainPath.new(from: 'Westport', to: 'Claremorris', dir: 'local', dep: dep_time,
                                      arr: arr_time, position: 'Claremorris', trip_id: trip_id, covey_id: trip_id, stops: stops)
                      end
        @claremorris_trains << local_train
      end
      # new dep_time and position
      arr_time = @claremorris_trains.last.arr
      dep_time = @claremorris_trains.last.arr + @min_dwell
      current_position = @claremorris_trains.last.to
      @trip_id_idx += 1
    end
    @train_trips = (@claremorris_trains + @trains).sort_by(&:dep)
  end
end

Option3.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
