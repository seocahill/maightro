#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo improved!
# Naive Algorithm:
# - Find and fix useless trains
# - Check if Ballina train can be inserted
# - If that doesn't wor alter Westport making sure path is available.
# - BMT duration is 27.  Minimum dwell is 3 minutes.

## TODO
# - dups
# - time dwells should match
# - costello


require 'uri'
require 'json'
require 'net/http'
# require 'pry'

require 'time'
require 'terminal-table'
require_relative 'option_1'

class Option1a
  include Helper

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @stop_info = YAML.load(File.read("config.yaml"))
    @dwell = 60.0
    @date = date
    @sort = sort
    @from = from
    @to = to
    @train_trips = list_train_trips
    fix_overlapping_trains # DEBUG
  end

  def list_train_trips
    all_trips = Option1.new(@date, "Ballyhaunis", "Westport").train_trips
    ballina_trains = []

    # FIXME group keys are wrong somehow

    # covey trains already grouped
    dir_westport_trains = all_trips.flatten.select { |t| t.info == 'to Westport' }
    dir_dub_trains = all_trips.flatten.select { |t| t.info == 'to Dublin Heuston' }

    dir_dub_trains.each do |ic|
      # mark as covey and nephin train
      ic.covey_id = ic.trip_id
      ic.nephin_id = ic.trip_id
      ic.costello_id = ic.trip_id
      from = ic.dep - (29 * 60) # 27 min + 2 dwell/transfer
      # group costello
      stops = stops('Ballina', 'Manulla Junction', from)
      ic.costello_id = ic.trip_id
      ballina_trains << TrainPath.new(from: 'Ballina', to: 'Manulla Junction', dep: from, arr: ic.dep, costello_id: ic.trip_id, stops: stops)

      depart_time = ic.arr
      arr_time = depart_time + (27 * 60)
      # group nephin
      stops = stops('Manulla Junction', 'Ballina', depart_time)
      ic.nephin_id =  ic.trip_id
      ballina_trains << TrainPath.new(from: 'Manulla Junction', to: 'Ballina', dep: depart_time, arr: arr_time,
                                      nephin_id: ic.trip_id, stops: stops)
    end

    dir_westport_trains.each do |ic|
      # all routes!
      ic.covey_id = ic.trip_id
      ic.costello_id = ic.trip_id
      ic.nephin_id = ic.trip_id
      from = ic.dep - (29 * 60) # 27 min + 2 dwell/transfer
      # group nephin
      stops = stops('Ballina', 'Manulla Junction', from)
      ballina_trains << TrainPath.new(from: 'Ballina', to: 'Manulla Junction', dep: from, arr: ic.dep, nephin_id: ic.trip_id, stops: stops)

      depart_time = ic.arr
      arr_time = depart_time + (27 * 60)
      # group costello
      ic.costello_id =  ic.trip_id
      stops = stops('Manulla Junction', 'Ballina', depart_time)
      ballina_trains << TrainPath.new(from: 'Manulla Junction', to: 'Ballina', dep: depart_time, arr: arr_time,
                                      costello_id: ic.trip_id, stops: stops)
    end

    ballina_trains + dir_westport_trains + dir_dub_trains
  end

  def fix_overlapping_trains
    # ballina westport connections need to be optimized
    # need to sort that's the issue
     @train_trips.reject {|t| t.nephin_id.nil? }.group_by(&:nephin_id).sort_by {|trip_id, trains| trains.map(&:dep).min }.each_cons(2) do |current, nxt|
      current_train_arr = current[1].flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.max { |a,b| a[1] <=> b[1] }.dig(1)
      next_train_dep = nxt[1].flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.min { |a,b| a[1] <=> b[1] }.dig(1)
      overlap = current_train_arr - next_train_dep
      if overlap.positive?
        nxt[1].each do |train|
          train.dep += (overlap + 180)
          train.arr += (overlap + 180)
          train.stops.each { |stop| stop[1] += (overlap + 180) }
          train.info = "advanced by #{overlap.fdiv(60)} mins to avoid clash"
        end
      end
    end
  end

  def rows
    # find route group from search terms: nephin, covey, costello
    routes, _stops = find_route(@from, @to)
    # seach can return multiple routes
    results = []
    routes.each do |route|
      # group by group trip ids
      rows = @train_trips.reject { |t| t.send("#{route}_id").nil? }.group_by(&:"#{route}_id").map do |trip_id, trains|
        # make this a hash instead, hashes are sorted in ruby so this will work
        stops = trains.flat_map { |train| train.stops }.sort_by { |stop| stop[1] }.each_with_object({}) { |i, obj| obj[i[0]] = i[1] } # join all stops and sort by time
        # filter by @from @to and add other tt info
        next unless stops[@from] && stops[@to]
        next unless stops[@from] < stops[@to]
        # return train result for tt
        [@from, @to, stops[@from].strftime("%H:%M"), stops[@to].strftime("%H:%M"), trains.map(&:info).join('; ')]
      end.compact
      results += rows
    end
    results
  end

  def as_ascii
    sort = %w[from to dep arr].index(@sort)
    headers = %w[from to dep arr]
    puts Terminal::Table.new rows: rows.sort_by { |r| r[sort] }, headings: headers, title: 'An Maightró', style: { all_separators: true }
  end
end

Option1a.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
