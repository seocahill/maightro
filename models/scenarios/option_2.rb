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

require_relative 'base_option'
require_relative 'option_1'

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

class Option2 < BaseOption

  attr_reader :train_trips

  def exec_option
    @train_trips = schedule_ballina_trains
  end

  def schedule_ballina_trains
    @local_trains = []
    @ic_trains = []

    connecting_trains = import_train_data("Ballyhaunis", "Westport").select { |t| t.stops.any? { |s| s[0] == 'Manulla Junction' } }

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')

    current_position = 'Ballina'

    # generate local trains from initial departure time until latest arrival time
    # connection train is Westport - Dublin, local train is Ballina - Westport
    @l_index = 0
    until arr_time > Time.parse('23:59')
      # get next 2 connects
      connecting_train, next_connection = connecting_trains.min_by(2, &:time_at_junction)
      # if can do full local trip generate train and add to timetable.
      # a connection train can be from B to connect with W or D going to D or W, or from W to connect with D, going to B.
      # variables are: dir of connecting train, current position of Ballina train, time of connection, earliest time Ballina train can leave
      if full_train_trip_possible(connecting_train, current_position, dep_time)
        add_local_train(current_position, dep_time)
      else
        # create train to meet connect
        # the destination of the local train is determined by the direction of the connecting train
        add_connecting_train(connecting_train, current_position, dep_time, next_connection)
        # and pop off connecting trains queue
        @ic_trains << connecting_train
        connecting_trains.delete connecting_train
      end
      # new dep_time and position
      arr_time = @local_trains.last.arr
      dep_time = @local_trains.last.arr + @turnaround
      current_position = @local_trains.last.position
      @l_index += 1
    end
    @local_trains + @ic_trains
  end

  def full_train_trip_possible(connecting_train, current_position, dep_time)
    # if no connecting train then possible by default
    return true unless connecting_train

    # dwell, time from current position to get to opposite position and back to junction (if applicable)
    return unless trip_duration = duration_of_trip_and_connection(connecting_train, current_position)

    dep_time + trip_duration < connecting_train.time_at_junction
  end

  def duration_of_trip_and_connection(connecting_train, current_position)
    if connecting_train.to == 'Westport' && current_position == 'Westport'
      duration("Westport", "Ballina") + @turnaround + duration("Ballina", "Manulla Junction")
    elsif connecting_train.to == 'Westport' && current_position == 'Ballina'
      duration("Ballina", "Westport") + @turnaround + duration("Westport", "Manulla Junction")
    elsif current_position == 'Ballina' # to dublin
      duration("Ballina", "Westport") + @turnaround + duration("Westport", "Ballina") + @turnaround + duration("Ballina", "Manulla Junction")
    elsif current_position == 'Westport'
      duration("Westport", "Ballina") + @turnaround +  duration("Ballina", "Manulla Junction")
    elsif current_position == 'Castlebar'
      false
    end
  end

  def add_local_train(current_position, dep_time)
    trip_id = "LDT-#{@l_index}"
    end_station = current_position == 'Ballina' ? 'Westport' : 'Ballina'
    stops = stops(current_position, end_station, dep_time)
    arr_time = dep_time + duration(current_position, end_station)
    local_train = TrainPath.new(from: current_position, to: end_station, dir: 'local', dep: dep_time, arr: arr_time,
                                   position: end_station, trip_id: trip_id, nephin_id: trip_id, stops: stops)
    @local_trains << local_train
    find_route(current_position, end_station).dig(0).each do |route|
      local_train.send("#{route}_id=", trip_id)
    end
  end

  def connection_info(dir, pos)
    return ['To Dublin', 'local'] if (dir == 'Dublin Heuston' && pos == 'Ballina')

    ['local', 'From Dublin']
  end

  def false_connection(connecting_train, local_train)
    # Ballina railcar continuing in same direction IC came from doesn't really connect even if technically true
    # puts "false connection found for #{connecting_train.trip_id}"
    connecting_train.dir == "Dublin Heuston" &&  %w[Westport Castlebar].include?(local_train.to)
  end

  # will comprise of two trips as railcar is always in B or W and must meet connect at M
  def add_connecting_train(connecting_train, current_position, _dep_time, next_connection)
    end_station = current_position == 'Ballina' ? 'Westport' : 'Ballina'
    # "time at junction" is actually time departing junction, add 1 min dwell
    arr = connecting_train.time_at_junction - @dwell
    dep = arr - duration(current_position, 'Manulla Junction')
    up_connection, down_connection = connection_info(connecting_train.dir, current_position)
    # train to connection from B or W dep on current position
    prev_train = @local_trains.last
    stops = stops(current_position, 'Manulla Junction', dep)

    up_train = TrainPath.new(from: current_position, to: 'Manulla Junction', dir: up_connection, dep: dep, arr: arr,
                             position: 'Manulla Junction', stops: stops)

    # assign train to up route/s
    find_route(current_position, connecting_train.stops.last[0]).dig(0).each do |route|
      next if false_connection(connecting_train, up_train)

      up_train.send("#{route}_id=", connecting_train.trip_id)
      connecting_train.send("#{route}_id=", connecting_train.trip_id)
    end

    # add train to collection
    @local_trains << up_train

    # train from Manulla to B or W dep on dir of connection and on timing of next connection
    dep = arr + @turnaround
    round_trip_time = duration("Westport", "Manulla Junction") + duration("Manulla Junction", "Westport") + @turnaround
    if next_connection && (next_connection.time_at_junction - @dwell - arr < round_trip_time)
      end_station = 'Castlebar'
      arr = dep + duration('Manulla Junction', end_station)
    else
      end_station = connecting_train.dir == 'Westport' ? 'Ballina' : 'Westport'
      arr = dep + duration('Manulla Junction', end_station)
    end
    stops = stops('Manulla Junction', end_station, dep)
    down_train = TrainPath.new(from: 'Manulla Junction', to: end_station, dir: down_connection, dep: dep, arr: arr,
                               position: end_station, stops: stops)
    # assign train to down route/s
    find_route(connecting_train.stops.first[0], end_station).dig(0).each do |route|
      next if false_connection(connecting_train, down_train)

      down_train.send("#{route}_id=", connecting_train.trip_id)
      connecting_train.send("#{route}_id=", connecting_train.trip_id)
    end

    @local_trains << down_train

    # Castlebar adjustment: In the case where train from Ballina must meet down Dublin and return, run to Castlebar if possible
    if up_train.from == 'Ballina' && down_train.to == 'Ballina'
      cbar_offset = duration("Castlebar", "Manulla Junction") + duration("Manulla Junction", "Castlebar") + @turnaround
      if up_train.dep - cbar_offset > prev_train.arr + @turnaround
        up_train.tap do |train|
          train.to = 'Castlebar'
          train.dep = train.dep - cbar_offset
          train.stops = stops(train.from, train.to, train.dep)
          train.arr = train.arr - cbar_offset + duration("Manulla Junction", "Castlebar")
          train.trip_id = "LCA-#{@l_index}"
          train.nephin_id = train.trip_id
        end
        down_train.tap do |train|
          train.from = 'Castlebar'
          train.dep = train.dep - duration("Castlebar", "Manulla Junction") - @turnaround
          train.stops = stops(train.from, train.to, train.dep)
          train.trip_id = "LCA-#{@l_index}"
          train.nephin_return_id = train.trip_id
        end
      end
    end

    # assign up and down train trip to routes if applicable
    find_route(up_train.from, down_train.to).dig(0).each do |route|
      trip_id = "LC-#{@l_index}"
      up_train.send("#{route}_id=", trip_id) if up_train.send("#{route}_id").nil?
      down_train.send("#{route}_id=", trip_id) if down_train.send("#{route}_id").nil?
    end

    @local_trains
  end
end

Option2.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
