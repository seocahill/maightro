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
require 'pry'
require 'pry-byebug'
require 'pry-rescue'
require 'pry-stack_explorer'

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

class Option3

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

    @cla_block = 14 * 60

    schedule_trains
  end

  #### Claremorris

  def train_in_wrong_position(connecting_train, _dep_time, current_position)
    if connecting_train.from == 'Ballina-Westport' && current_position == 'Westport'
      false
    elsif connecting_train.from == 'Westport-Ballina' && current_position == 'Claremorris'
      false
    else
      true
    end
  end

# TODO: Add claremorris local trains

  def schedule_trains
    @results = JourneyPlanner.new.search(@date, @from, @to)
    timetable = Option1.new.train_trips
    connecting_trains = timetable.select { |t| [t.from, t.to].include? "Westport" }
    first_ballina_train = timetable.first

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')
    current_position = 'Claremorris'
    ballina_trains = @local_trains.select { |t| %w[Ballina-Westport Westport-Ballina].include? t.from }

    until arr_time > Time.parse('23:59')
      # get next 2 connects
      if connecting_train = ballina_trains.first
        connecting_time = connecting_train.from == 'Ballina-Westport' ? connecting_train.dep + @bal_block : connecting_train.dep + @wes_block
        # Need to check here if the local Clare train is in correct position e.g:
        # If meeting ex Ballina needs to be in Westport
        # If meeting ex Westport needs to be in Claremorris
        if train_in_wrong_position(connecting_train, dep_time, current_position)
          @claremorris_trains << if current_position == 'Claremorris'
                                  # no dwell in manulla
                                  TrainPath.new('Claremorris-Westport', 'local', dep_time,
                                                dep_time + @cla_block + @wes_block, 'Westport')
                                else
                                  TrainPath.new('Westport-Claremorris', 'local', dep_time,
                                                dep_time + @cla_block + @wes_block, 'Claremorris')
                                end
        else
          # create train to meet connect
          if current_position == 'Claremorris'
            description = 'Claremorris-Westport'
            dep_time = connecting_time - @cla_block
            arr_time = dep_time + @min_dwell + @wes_block
          else
            description = 'Westport-Claremorris'
            dep_time = connecting_time - @wes_block
            arr_time = dep_time + @min_dwell + @cla_block
          end
          @claremorris_trains << TrainPath.new(description, connecting_train.dir, dep_time, arr_time,
                                              description.split('-').last)
          # and pop off connecting trains queue
          ballina_trains.delete connecting_train
        end
      else
        # just make local train
        @claremorris_trains << if current_position == 'Claremorris'
                                # no dwell in manulla
                                TrainPath.new('Claremorris-Westport', 'local', dep_time,
                                              dep_time + @cla_block + @wes_block, 'Westport')
                              else
                                TrainPath.new('Westport-Claremorris', 'local', dep_time,
                                              dep_time + @cla_block + @wes_block, 'Claremorris')
                              end
      end
      # new dep_time and position
      arr_time = @claremorris_trains.last.arr
      dep_time = @claremorris_trains.last.arr + @min_dwell
      current_position = @claremorris_trains.last.position
    end
  end

  def as_ascii
    rows = (@claremorris_trains + @ic_trains).sort_by(&:dep)
    [nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
      cur.position = if prev.nil?
                      0
                    else
                      (cur.dep - prev.arr).fdiv(60).round
                    end
    end
    puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró (glas)', style: { all_separators: true }
    puts '========='
    ex_wc_to_clare = rows.select do |r|
      r.from.split('-').first == 'Westport'
    end.map { |t| t.dep.strftime('%H:%M') }.join(', ')
    puts "ex Westport: #{ex_wc_to_clare}"
    puts '========='
    ex_clare_to_wc = rows.select do |r|
      r.from.split('-').first == 'Claremorris'
    end.map { |t| t.dep.strftime('%H:%M') }.join(', ')
    puts "ex Claremorris #{ex_clare_to_wc}"
    puts '========='

    ## WCW services
    puts '=' * 99
    puts 'Trains serving Castlebar and Westport'
    puts '=' * 99
    puts "to Castlebar/Westport: #{(ex_b_to_wc.split(',') + ex_clare_to_wc.split(',')).sort.join(', ')}"
    puts '========='
    puts "from Castlebar/Westport #{(ex_cw_to_b.split(',') + ex_wc_to_clare.split(',')).sort.join(', ')}"
    puts '========='
  end

  def as_json
    File.open("dispatch.json", "w") do |file|
      file.write (@local_trains + @claremorris_trains + @ic_trains).sort_by(&:dep).map { |t| t.to_h.to_json }
    end
  end
end

Option3.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
