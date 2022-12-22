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
require_relative 'journey_planner'
require_relative 'option_3'


class Option3b

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @min_dwell = 180
    @haunis_block = 15 * 3600

    @date = date
    @from = from
    @to = to
    @sort = sort
    @haunis_trains = []

    schedule_trains
  end

  #### Ballyhaunis - Claremorris block

  def schedule_trains
    @ic_trains = Option1.new(@date, "Ballyhaunis", "Westport").train_trips
    @claremorris_trains = Option3.new.claremorris_trains

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
          connecting_train.to = "Ballyhaunis"
        else # going to Westport
          # if block free
          # start train from haunis instead
          # @haunis_trains
          connecting_train.dep -= (@haunis_block + @min_dwell)
          connecting_train.from = "Ballyhaunis"
        end
      end
      @haunis_trains << connecting_train
      @claremorris_trains.delete connecting_train
    end
  end

  def as_ascii
    rows = (@haunis_trains).sort_by(&:dep)
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

Option3b.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
