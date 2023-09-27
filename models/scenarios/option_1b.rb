#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo improved!
# Naive Algorithm:
# - Find and fix useless trains
# - Check if Ballina train can be inserted
# - If that doesn't work alter Westport making sure path is available (todo)
# - BMT duration is 27.  Minimum dwell is 3 minutes.

## TODO
# - standardize time lookup
# - refactor
# - would be nice to check if train can be reschudled i.e
# - get all trains on port - wes for window and see if can be crossed at station, adjust.

require_relative 'base_option'
require_relative 'option_1'

class Option1b < BaseOption

  def exec_option
    @train_trips = schedule_train_trips
    fix_overlapping_trains # DEBUG
  end

  def schedule_train_trips
    ic_trips = import_train_data("Ballyhaunis", "Westport").flatten
    ic_trips = (ic_trips + new_trains).sort_by { |t| [t.dir, t.dep] }
    ballina_trains = []

    # covey trains already grouped
    branch_trip_time = duration('Ballina', 'Manulla Junction')

    ic_trips.each do |ic|
      next unless ic.time_at_junction # i.e. extra friday train to westport only

      dep_ballina = ic.time_at_junction - branch_trip_time - @dwell
      stops = stops('Ballina', 'Manulla Junction', dep_ballina)
      train_up = TrainPath.new(from: 'Ballina', to: 'Manulla Junction', dep: dep_ballina, arr: ic.dep, stops: stops)
      find_route('Ballina', ic.stops.last[0]).dig(0).each do |route|
        train_up.send("#{route}_id=", ic.trip_id)
        ic.send("#{route}_id=", ic.trip_id)
      end
      ballina_trains << train_up

      arr_time = ic.time_at_junction + branch_trip_time
      stops = stops('Manulla Junction', 'Ballina', ic.time_at_junction)
      train_down = TrainPath.new(from: 'Manulla Junction', to: 'Ballina', dep: ic.time_at_junction, arr: arr_time, stops: stops)
      find_route(ic.stops.first[0], 'Ballina').dig(0).each do |route|
        train_down.send("#{route}_id=", ic.trip_id)
        ic.send("#{route}_id=", ic.trip_id)
      end
      ballina_trains << train_down
    end

    ballina_trains + ic_trips
  end

  def fix_overlapping_trains
    # TODO: when changing check path exists on Dublin - Westport.
    nephin_trains = @train_trips.reject {|t| t.nephin_id.nil? }.group_by(&:nephin_id).map { |t| t[1] }
    return_trains = @train_trips.reject {|t| t.nephin_return_id.nil? }.group_by(&:nephin_return_id).map { |t| t[1] }
    sorted_trains = (nephin_trains + return_trains).sort_by {|trains| trains.map(&:dep).min }
    sorted_trains.each_cons(2) do |current, nxt|
      current_train_arr = current.flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.max { |a,b| a[1] <=> b[1] }.dig(1)
      next_train_dep = nxt.flat_map { |t| t.stops }.select { |s| %w[Ballina Westport].include?(s[0]) }.min { |a,b| a[1] <=> b[1] }.dig(1)
      overlap = current_train_arr - next_train_dep
      if overlap > -(@turnaround) # must be within min turnaround time
        adjustment = overlap + @turnaround
        nxt.each do |train|
          train.dep += adjustment
          train.arr += adjustment
          train.stops.each { |stop| stop[1] += adjustment }
          train.info = "advanced by #{adjustment.fdiv(60)} mins to avoid clash"
        end
      end
    end
  end
end

def new_trains
  # new trains only run mon-sat
  return [] if Date.parse(@date).wday == 0
  # parse_time(
  dub = TrainPath.new(
    arr: Time.parse("17:12"),
    covey_id: "R-10",
    dep:  Time.parse("16:20"),
    dir: "Dublin Heuston",
    from: "Westport",
    info: "to Dublin Heuston",
    stops:
    [["Westport",  Time.parse("16:20")],
      ["Castlebar",  Time.parse("16:23")],
      ["Manulla Junction",  Time.parse("16:37")],
      ["Claremorris",  Time.parse("16:54")],
      ["Ballyhaunis",  Time.parse("17:12")]],
    to: "Ballyhaunis",
    trip_id: "R-10"
  )
  wes = TrainPath.new(
    arr:  Time.parse("22:53"),
    covey_return_id: "C-5",
    dep:  Time.parse("22:01"),
    dir: "Westport",
    from: "Ballyhaunis",
    info: "to Westport",
    stops:
    [["Ballyhaunis",  Time.parse("22:01")],
      ["Claremorris",  Time.parse("22:16")],
      ["Manulla Junction",  Time.parse("22:30")],
      ["Castlebar",  Time.parse("22:36")],
      ["Westport",  Time.parse("22:53")]],
    to: "Westport",
    trip_id: "C-5"
  )
  [dub, wes]
end

Option1b.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
