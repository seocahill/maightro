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
    @claremorris_trains = []
    schedule_trains
  end

  #### Claremorris

  def train_in_wrong_position(connecting_train, _dep_time, current_position)
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
    @ballina_trains = Option2.new.schedule_ballina_trains
    @ic_trains = Option1.new(@date, "Claremorris", "Westport").train_trips

    dep_time = Time.parse('05:00')
    arr_time = Time.parse('05:00')
    current_position = 'Claremorris'
    # the ballina castlebar trains are extended connectors ignore them
    @connecting_trains = @ballina_trains.select { |t| [["Ballina", "Westport"]].include? [t.from, t.to].sort }

    until arr_time > Time.parse('23:59')
      # get next 2 connects
      if connecting_train = @connecting_trains.first
        # Need to check here if the local Clare train is in correct position e.g:
        # If meeting ex Ballina needs to be in Westport
        # If meeting ex Westport needs to be in Claremorris
        # if connecting_train&.trip_id =~ /^(C|R)-[0-9]$/
        #   @connecting_trains.delete connecting_train
        if train_in_wrong_position(connecting_train, dep_time, current_position)
          train = if current_position == 'Claremorris'
                    # no dwell in manulla
                    TrainPath.new(from: "Claremorris", to: "Westport", info: 'local', dep: dep_time,
                                  arr: dep_time + @cla_block + @wes_block, position: 'Westport', trip_id: "LW")
                  else
                    TrainPath.new(from: 'Westport', to: 'Claremorris', info: 'local', dep: dep_time,
                                  arr: dep_time + @cla_block + @wes_block, position: 'Claremorris', trip_id: "LC")
                  end
          @claremorris_trains << train
        else
          # calculate connecting time
          connecting_time = if connecting_train.from == 'Ballina'
            connecting_train.dep + @bal_block
          elsif  connecting_train.from == 'Westport'
            connecting_train.dep + @wes_block
          else # castlebar
            connecting_train.dep + @man_cas_block
          end
          # create train to meet connect
          if current_position == 'Claremorris'
            from = 'Claremorris'
            to = 'Westport'
            dep_time = connecting_time - @cla_block
            arr_time = dep_time + @min_dwell + @wes_block
          else
            from = 'Westport'
            to = 'Claremorris'
            dep_time = connecting_time - @wes_block
            arr_time = dep_time + @min_dwell + @cla_block
          end

          @claremorris_trains << TrainPath.new(from: from, to: to, dir: connecting_train.dir, dep: dep_time, arr: arr_time,
                                              position: to, trip_id: connecting_train.trip_id)
          # and pop off connecting trains queue
          @connecting_trains.delete connecting_train
        end
      else
        # just make local train
        local_train = if current_position == 'Claremorris'
                                # no dwell in manulla
                                TrainPath.new(from: 'Claremorris', to: 'Westport', dir: 'local', dep: dep_time,
                                              arr: dep_time + @cla_block + @wes_block, position: 'Westport', trip_id: "LW")
                              else
                                TrainPath.new(from: 'Westport', to: 'Claremorris', dir: 'local', dep: dep_time,
                                              arr: dep_time + @cla_block + @wes_block, position: 'Claremorris', trip_id: "LC")
                              end
        @claremorris_trains << local_train
      end
      # new dep_time and position
      arr_time = @claremorris_trains.last.arr
      dep_time = @claremorris_trains.last.arr + @min_dwell
      current_position = @claremorris_trains.last.position
    end
  end

  def claremorris_trains
    (@claremorris_trains + @ic_trains).sort_by(&:dep)
  end

  def as_ascii
    rows = (@claremorris_trains + @ic_trains).sort_by(&:dep)
    [nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
      next if prev.nil?
      prev.position = (cur.dep - prev.arr).fdiv(60).round
    end
    headers = %w[from to dep arr dwell dir connection]
    puts Terminal::Table.new rows: rows.map { |t| [t.from, t.to, t.dep_time, t.arr_time, t.position, t.dir, t.trip_id] }, headings: headers, title: 'An Maightró (glas)', style: { all_separators: true }

    ## WCW services
    # puts '=' * 99
    # puts 'Trains serving Castlebar and Westport'
    # puts '=' * 99
    # puts "to Castlebar/Westport: #{(ex_b_to_wc.split(',') + ex_clare_to_wc.split(',')).sort.join(', ')}"
    # puts '========='
    # puts "from Castlebar/Westport #{(ex_cw_to_b.split(',') + ex_wc_to_clare.split(',')).sort.join(', ')}"
    # puts '========='

    ## Freight paths
    # TODO
  end

  def as_json
    File.open("dispatch.json", "w") do |file|
      file.write (@local_trains + @claremorris_trains + @ic_trains).sort_by(&:dep).map { |t| t.to_h.to_json }
    end
  end
end

Option3.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
