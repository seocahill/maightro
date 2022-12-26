#! /usr/bin/ruby
# frozen_string_literal: true

# Add Ballyhaunis block (15 mins)

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
require_relative 'option_3'

class Option3b
  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @min_dwell = 180
    @haunis_block = 16 * 60 # include 1 min dwell just to make it easier
    @clare_west_block = 37 * 60 # from tt.

    @date = date
    @from = from
    @to = to
    @sort = sort
    @haunis_trains = []

    schedule_trains
  end

  #### Ballyhaunis - Claremorris block

  def schedule_trains
    @ic_trains = Option1.new(@date, 'Ballyhaunis', 'Westport').train_trips
    @claremorris_trains = Option3.new(@date).claremorris_trains

    until @claremorris_trains.empty?
      # get next 2 connects
      if connecting_train = @claremorris_trains.first
        # calculate connecting time
        # create train to meet connect
        if connecting_train.from == 'Westport'
          # and block free
          # send train to haunis
          # @haunis_trains
          connecting_train.arr += @haunis_block
          connecting_train.to = 'Ballyhaunis'
        else # going to Westport
          # if block free
          # start train from haunis instead
          # @haunis_trains
          connecting_train.dep -= @haunis_block
          connecting_train.from = 'Ballyhaunis'
        end
      end
      @haunis_trains << connecting_train
      @claremorris_trains.delete connecting_train
    end
    attempt_to_cross_trains
  end

  def attempt_to_cross_trains
    trains = @haunis_trains.sort_by(&:dep)
    [nil, *trains, nil].each_cons(3) do |(prev, cur, _nxt)|
      next if prev.nil?

      prev.position = (cur.dep - prev.arr).fdiv(60).round
      next unless prev.position.negative?

      p_cross_time = prev.from == 'Westport' ? prev.arr - @haunis_block : prev.dep + @haunis_block
      c_cross_time = cur.from == 'Westport' ? cur.arr - @haunis_block : cur.dep + @haunis_block
      if (p_cross_time - c_cross_time).abs <= 3
        prev.dir = "crosses at #{p_cross_time.strftime('%H:%M')}"
        cur.dir = "crosses at #{c_cross_time.strftime('%H:%M')}"
      else
        @haunis_trains.delete prev
      end
    end
  end

  def rows
    @haunis_trains
      .sort_by(&:dep)
      .map { |t| [t.from, t.to, t.dep_time, t.arr_time, t.position, t.dir, t.trip_id] }
  end

  def as_ascii
    headers = %w[from to dep arr dwell dir connection]
    puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró (glas)', style: { all_separators: true }

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
    File.open('dispatch.json', 'w') do |file|
      file.write(@local_trains + @claremorris_trains + @ic_trains).sort_by(&:dep).map { |t| t.to_h.to_json }
    end
  end
end

Option3b.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
