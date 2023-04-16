#! /usr/bin/ruby
# frozen_string_literal: true

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
  attr_reader :claremorris_trains

  def exec_option
    @claremorris_trains = []
    @covey_terminus = "Claremorris"
    @trip_id_idx = 0
    schedule_trains
  end

  #### Claremorris

  def train_in_wrong_position(connecting_train, current_position)
    return unless connecting_train

    if connecting_train.from == 'Ballina' && current_position == 'Westport'
      false
    elsif connecting_train.from == 'Westport' && current_position == @covey_terminus
      false
    elsif connecting_train.from == 'Castlebar' && current_position == @covey_terminus
      false
    else
      true
    end
  end

  # Add claremorris local trains

  def connecting_train_possible(connecting_train, current_position, dep_time)
    return unless connecting_train
    if current_position == @covey_terminus
      dep_time <= connecting_train.time_at_junction - duration(@covey_terminus, "Manulla Junction")
    else
      dep_time <= connecting_train.time_at_junction - duration("Westport", "Manulla Junction")
    end
  end

  def schedule_trains
    @trains = Option2.new(@date).train_trips

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')
    current_position = @covey_terminus
    # the ballina castlebar trains are extended connectors ignore them
    @connecting_trains = @trains.select { |t| [%w[Ballina Westport]].include? [t.from, t.to].sort }

    until arr_time > Time.parse('23:59')
      # get next 2 connects
      connecting_train = @connecting_trains.first
      # Need to check here if the local Clare train is in correct position e.g:
      # If meeting ex Ballina needs to be in Westport
      # If meeting ex Westport needs to be in Claremorris
      # if connecting_train&.trip_id =~ /^(C|R)-[0-9]$/
      #   @connecting_trains.delete connecting_train
      train = if train_in_wrong_position(connecting_train, current_position)
                trip_id = "LCTR-#{@trip_id_idx}"
                if current_position == @covey_terminus
                  # no dwell in manulla
                  arr_time = dep_time + duration(@covey_terminus, "Westport")
                  stops = stops(@covey_terminus, "Westport", dep_time)
                  TrainPath.new(from: @covey_terminus, to: 'Westport', info: 'local', dep: dep_time,
                                arr: arr_time, position: 'Westport', trip_id: trip_id, covey_return_id: trip_id, stops: stops)
                else
                  arr_time = dep_time + duration("Westport", @covey_terminus)
                  stops = stops("Westport", @covey_terminus, dep_time)
                  TrainPath.new(from: 'Westport', to: @covey_terminus, info: 'local', dep: dep_time,
                                arr: arr_time, position: @covey_terminus, trip_id: trip_id, covey_id: trip_id, stops: stops)
                end
              elsif connecting_train_possible(connecting_train, current_position, dep_time)
                trip_id = "LCX-#{@trip_id_idx}"
                # create train to meet connect if possible
                train = if current_position == @covey_terminus
                          dep_time = connecting_train.time_at_junction - duration(@covey_terminus, "Manulla Junction")
                          arr_time = connecting_train.time_at_junction + duration("Manulla Junction", "Westport")
                          stops = stops(@covey_terminus, "Westport", dep_time)
                          TrainPath.new(from: @covey_terminus, to: 'Westport', dep: dep_time, arr: arr_time, trip_id: connecting_train.trip_id, stops: stops, covey_return_id: trip_id)
                        else
                          dep_time = connecting_train.time_at_junction - duration("Westport", "Manulla Junction")
                          arr_time = connecting_train.time_at_junction + duration("Manulla Junction", @covey_terminus)
                          stops = stops("Westport", @covey_terminus, dep_time)
                          TrainPath.new(from: 'Westport', to: @covey_terminus, dep: dep_time, arr: arr_time, trip_id: connecting_train.trip_id, stops: stops, covey_id: trip_id)
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
                # and pop off connecting trains queue
                @connecting_trains.delete connecting_train
                # return train
                train
              else
                # just make local train
                trip_id = "LCL-#{@trip_id_idx}"
                train = if current_position == @covey_terminus
                          # no dwell in manulla
                          stops = stops(@covey_terminus, "Westport", dep_time)
                          arr_time = dep_time + duration(@covey_terminus, "Westport")
                          TrainPath.new(from: @covey_terminus, to: 'Westport', dir: 'local', dep: dep_time,
                                        arr: arr_time, position: 'Westport', trip_id: trip_id, covey_return_id: trip_id, stops: stops)
                        else
                          stops = stops("Westport", @covey_terminus, dep_time)
                          arr_time = dep_time + duration("Westport", @covey_terminus)
                          TrainPath.new(from: 'Westport', to: @covey_terminus, dir: 'local', dep: dep_time,
                                        arr: arr_time, position: @covey_terminus, trip_id: trip_id, covey_id: trip_id, stops: stops)
                        end
                # connecting train processed
                @connecting_trains.delete connecting_train
                # return train
                train
              end
      @claremorris_trains << train
      # new dep_time and position
      arr_time = @claremorris_trains.last.arr
      dep_time = @claremorris_trains.last.arr + @turnaround
      current_position = @claremorris_trains.last.to
      @trip_id_idx += 1
    end
    @train_trips = (@claremorris_trains + @trains).sort_by(&:dep)
  end
end

Option3.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
