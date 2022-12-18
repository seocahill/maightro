#! /usr/bin/ruby
# frozen_string_literal: true

# Direct Algorithm:
# - Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
# - In this simulation no freight paths are included. Variables like staff, fuel etc are assumed to be sufficient.
# - BMT duration is 27.  Minimum dwell is 3 minutes. WMT duration is 19 mins.
# - Loop from start to end time creating local or connecting trains depending on path availability
# Fixme: Train times overlap, shouldn't be possible

require 'uri'
require 'json'
require 'net/http'
require 'pry'
require 'pry-byebug'

require 'time'
require 'terminal-table'
require_relative 'option_2'
require_relative 'journey_planner'
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

class Option2

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @min_dwell = 180
    @bal_block = 27 * 60
    @wes_block = 19 * 60
    @man_cas_block = 6 * 60
    @one_day = 24 * 3600
    @date = date
    @from = from
    @to = to
    @sort = sort

    @local_trains = []
    @full_trip = @bal_block + @min_dwell + @wes_block
  end

  def schedule_trains
    @results = JourneyPlanner.new.search(@date, @from, @to)
    timetable = Option1.new.train_trips
    manulla_times = timetable.select { |t| [t.to, t.from].sort == ["Ballina", "Manulla Junction"] }
    first_ballina_train = timetable.first
    train_location = 'Ballina'
    dep_time = first_ballina_train.dep


    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')

    transfer = manulla_times.sort_by { |t| t.arr || t.dep }

    current_position = 'Ballina'

    # generate local trains from initial departure time until latest arrival time
    # connection train is Westport - Dublin, local train is Ballina - Westport
    until arr_time > Time.parse('23:59')
      # get next 2 connects
      connecting_train, next_connection = manulla_times.min_by(2) { |t| t.arr || t.dep }
      # if can do full local trip generate train and add to timetable.
      # a connection train can be from B to connect with W or D going to D or W, or from W to connect with D, going to B.
      # variables are: dir of connecting train, current position of Ballina train, time of connection, earliest time Ballina train can leave
      # binding.pry
      if full_train_trip_possible(connecting_train, current_position, dep_time)
        add_local_train(current_position, dep_time)
      else
        # create train to meet connect
        # the destination of the local train is determined by the direction of the connecting train
        add_connecting_train(connecting_train, current_position, dep_time, next_connection)
        # and pop off connecting trains queue
        manulla_times.delete connecting_train
      end
      # new dep_time and position
      arr_time = @local_trains.last.arr
      dep_time = @local_trains.last.arr + @min_dwell
      current_position = @local_trains.last.position
    end
    @local_trains
  end

  def full_train_trip_possible(_connecting_train, _current_position, _dep_time)
    # if no connecting train then possible by default
    return true unless _connecting_train

    # dwell, time from current position to get to opposite position and back to junction (if applicable)
    trip_duration = if _connecting_train.dir == 'Westport' && _current_position == 'Westport'
                      @full_trip + @min_dwell + @bal_block
                    elsif _connecting_train.dir == 'Westport' && _current_position == 'Ballina'
                      @full_trip + @min_dwell + @wes_block
                    elsif _current_position == 'Ballina' # to dublin
                      @full_trip + @min_dwell + @full_trip + @min_dwell + @bal_block
                    elsif _current_position == 'Westport'
                      @full_trip + @min_dwell + @bal_block
                    elsif _current_position == 'Castlebar'
                      return false
                    end

    _dep_time + trip_duration < _connecting_train.time
  end

  def add_local_train(current_position, dep_time)
    end_station = current_position == 'Ballina' ? 'Westport' : 'Ballina'
    @local_trains << TrainPath.new(from: current_position, to: end_station, dir: 'local', dep: dep_time, arr: dep_time + @full_trip,
                                  position: end_station)
  end

  def connection_info(_dir, _pos)
    if _dir == 'Dublin Heuston' && _pos == 'Ballina'
      ['To Dublin', 'local']
    else
      ['local', 'From Dublin']
    end
  end

  def add_connecting_train(_connecting_train, _current_position, _dep_time, _next_connection)
    end_station = _current_position == 'Ballina' ? 'Westport' : 'Ballina'
    # times must be relative to connection (and origin station) not _dep_time!
    dep = case _current_position
          when 'Ballina'
            _connecting_train.time - @bal_block
          when 'Castlebar'
            _connecting_train.time -  @man_cas_block
          else
            _connecting_train.time -  @wes_block
          end
    arr = _connecting_train.time
    up_connection, down_connection = connection_info(_connecting_train.dir, _current_position)

    # train to connection from B or W dep on current position
    @local_trains << TrainPath.new(from: _current_position, to: "Manulla", dir: up_connection, dep: dep, arr: arr, position: "Manulla")

    # train from Manulla to B or W dep on dir of connection and on timing of next connection
    dep = arr + @min_dwell
    if _next_connection && (_next_connection.time - arr < ((@wes_block * 2) + @min_dwell))
      end_station = 'Castlebar'
      arr = dep + @man_cas_block
    else
      end_station = _connecting_train.dir == 'Westport' ? 'Ballina' : 'Westport'
      arr = dep + (end_station == 'Westport' ? @wes_block : @bal_block)
    end
    @local_trains << TrainPath.new(from: "Manulla", to: end_station, dir: down_connection, dep: dep, arr: arr, position: end_station)
  end

  def as_ascii
    headers = %w[path connection dep arr dwell]
    rows = schedule_trains # .sort_by(&:dep)
    [nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
      cur.position = if prev.nil?
                      0
                    else
                      (cur.dep - prev.arr).fdiv(60).round
                    end
    end
    puts Terminal::Table.new rows: rows.map(&:values), headings: headers, title: 'An Maightró', style: { all_separators: true }
    # puts '========='
    # puts "ex Ballina: #{@rows.select do |r|
    #   r.from.split('-').first == 'Ballina'
    # end.map { |t| t.dep.strftime('%H:%M') }.join(', ')}"
    # puts '========='
    # puts "ex Castlebar/Westport #{@rows.select do |r|
    #   r.from.split('-').first.match(/(Castlebar|Westport)/)
    # end.map { |t| t.dep.strftime('%H:%M') }.join(', ')}"
    # puts '========='
  end
end

Option2.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
