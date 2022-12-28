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
require_relative 'option_2'
require_relative '../journey_planner'
require_relative '../helper'
require 'terminal-table'
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
  include Helper

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @min_dwell = 180
    @bal_block = 27 * 60
    @wes_block = 19 * 60
    @man_cas_block = 6 * 60
    @one_day = 24 * 3600
    @full_trip = @bal_block + @min_dwell + @wes_block

    @date = date
    @from = from
    @to = to
    @sort = sort
    @local_trains = []
  end

  def schedule_ballina_trains
    @results = JourneyPlanner.new.search(@date, @from, @to)
    timetable = Option1.new.train_trips
    connecting_trains = timetable.select { |t| [t.from, t.to].include? 'Westport' }
    first_ballina_train = timetable.first

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')

    current_position = 'Ballina'

    # generate local trains from initial departure time until latest arrival time
    # connection train is Westport - Dublin, local train is Ballina - Westport
    @l_index = 0
    until arr_time > Time.parse('23:59')
      # get next 2 connects
      connecting_train, next_connection = connecting_trains.min_by(2, &:manulla_time)
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
        connecting_trains.delete connecting_train
      end
      # new dep_time and position
      arr_time = @local_trains.last.arr
      dep_time = @local_trains.last.arr + @min_dwell
      current_position = @local_trains.last.position
      @l_index += 1
    end
    @local_trains
  end

  def full_train_trip_possible(_connecting_train, _current_position, _dep_time)
    # if no connecting train then possible by default
    return true unless _connecting_train

    # dwell, time from current position to get to opposite position and back to junction (if applicable)
    trip_duration = if _connecting_train.to == 'Westport' && _current_position == 'Westport'
                      @full_trip + @min_dwell + @bal_block
                    elsif _connecting_train.to == 'Westport' && _current_position == 'Ballina'
                      @full_trip + @min_dwell + @wes_block
                    elsif _current_position == 'Ballina' # to dublin
                      @full_trip + @min_dwell + @full_trip + @min_dwell + @bal_block
                    elsif _current_position == 'Westport'
                      @full_trip + @min_dwell + @bal_block
                    elsif _current_position == 'Castlebar'
                      return false
                    end

    _dep_time + trip_duration < _connecting_train.manulla_time
  end

  def add_local_train(current_position, dep_time)
    end_station = current_position == 'Ballina' ? 'Westport' : 'Ballina'
    @local_trains << TrainPath.new(from: current_position, to: end_station, dir: 'local', dep: dep_time, arr: dep_time + @full_trip,
                                   position: end_station, trip_id: "LT-#{@l_index}")
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
            _connecting_train.manulla_time - @bal_block
          when 'Castlebar'
            _connecting_train.manulla_time -  @man_cas_block
          else
            _connecting_train.manulla_time -  @wes_block
          end
    arr = _connecting_train.manulla_time
    up_connection, down_connection = connection_info(_connecting_train.dir, _current_position)
    # train to connection from B or W dep on current position
    prev_train = @local_trains.last
    up_train = TrainPath.new(from: _current_position, to: 'Manulla', dir: up_connection, dep: dep, arr: arr,
                             position: 'Manulla', trip_id: _connecting_train.trip_id)
    @local_trains << up_train

    # train from Manulla to B or W dep on dir of connection and on timing of next connection
    dep = arr + @min_dwell
    if _next_connection && (_next_connection.manulla_time - arr < ((@wes_block * 2) + @min_dwell))
      end_station = 'Castlebar'
      arr = dep + @man_cas_block
    else
      end_station = _connecting_train.dir == 'Westport' ? 'Ballina' : 'Westport'
      arr = dep + (end_station == 'Westport' ? @wes_block : @bal_block)
    end
    down_train = TrainPath.new(from: 'Manulla', to: end_station, dir: down_connection, dep: dep, arr: arr,
                               position: end_station, trip_id: _connecting_train.trip_id)
    @local_trains << down_train

    # In the case where train from Ballina must meet down Dublin and return, adj to Castlebar if possible
    if up_train.from == 'Ballina' && down_train.to == 'Ballina'
      cbar_offset = (@man_cas_block * 2) + @min_dwell
      if up_train.dep - cbar_offset > prev_train.arr + @min_dwell
        up_train.to = 'Castlebar'
        down_train.from = 'Castlebar'
        up_train.dep = up_train.dep - cbar_offset
        up_train.arr = up_train.arr - cbar_offset + @man_cas_block
        down_train.dep = down_train.dep - @man_cas_block - @min_dwell
        up_train.trip_id = "LC-#{@l_index}"
      end
    end
    @local_trains
  end

  def rows
    rows = schedule_ballina_trains.group_by(&:trip_id).map do |_g, t|
      if t.length == 2
        ot, rt = t
        [ot.from, rt.to, ot.dep.strftime('%H:%M'), rt.arr.strftime('%H:%M'), (rt.arr - ot.dep).fdiv(60).round,
         ot.trip_id]
      else
        [t.first.from, t.first.to, t.first.dep.strftime('%H:%M'), t.first.arr.strftime('%H:%M'), (t.first.arr - t.first.dep).fdiv(60).round,
         t.first.trip_id]
      end
    end.sort_by { |t| [t[2]] }

    # calculate dwell
    rows.each_cons(2) do |current, nxt|
      unless nxt
        current[6] = 0
        next
      end

      current[6] = (Time.parse(nxt[2]) - Time.parse(current[3])).fdiv(60)
    end

    # calculate stops
    rows.each do |r|
       r << stops(r)
    end
    # [nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
    #   cur.position = if prev.nil?
    #                   0
    #                 else
    #                   (cur.dep - prev.arr).fdiv(60).round
    #                 end
    # end
    # rows = schedule_ballina_trains.map(&:values).sort_by { |t| t[4] }
  end

  def as_ascii
    sort = %w[from to dep arr].index(@sort)
    headers = %w[from to dep arr duration connection dwell]
    puts Terminal::Table.new rows: rows.map(&:compact), headings: headers, title: 'An Maightró',
                             style: { all_separators: true }
    # puts '========='
    # puts "ex Ballina: #{@rows.select do |r|
    #   r.from.split('-').first == 'Ballina'
    # end.map { |t| t.dep.strftime('%H:%M') }.join(', ')}"
    # puts '========='
    # puts "ex Castlebar/Westport #{@rows.select do |r|
    #   r.from.split('-').first.match(/(Castlebar|Westport)/)
    # end.map { |t| t.dep.strftime('%H:%M') }.join(', ')}"
    # puts '========='
    counts = rows.group_by { |r| [r[0], r[1]] }.map { |g, t| g << t.count }
    headers = %w[from to trains]
    puts Terminal::Table.new rows: counts, headings: headers, title: 'An Maightró', style: { all_separators: true }
  end
end

Option2.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
