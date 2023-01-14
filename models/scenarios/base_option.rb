#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo

require 'json'
require 'time'
require 'terminal-table'
require_relative '../helper'
require_relative '../journey_planner'
require_relative '../train_path'

class BaseOption
  include Helper

  def initialize(date = '20221222', from = 'Ballina', to = 'Westport', sort = 'dep')
    @stop_info = YAML.load(File.read("config.yaml"))
    @dwell = 60.0
    @turnaround = @dwell * 3
    @date = date
    @sort = sort
    @from = from
    @to = to
    exec_option
  end

  def exec_option
    raise "Implement me"
  end

  def import_train_data(from, to)
    results = JourneyPlanner.new.search(@date, from, to)

    [].tap do |trains|
      results.trains_out.each do |trip|
        routes, _stops = find_route(from, to)
        add_trains(trains, trip, routes, results.stations)
      end

      results.trains_ret.each do |trip|
        routes, _stops = find_route(to, from)
        add_trains(trains, trip, routes, results.stations)
      end
    end
  end

  def add_trains(trains, trip, routes, stations)
    trip['secL'].each do |train|
      train = TrainPath.create(train, trip, stations)
      routes.each { |route| train.send("#{route}_id=", train.trip_id) }
      trains << train
    end
  end

  def generate_configuration
    date = Time.now.strftime "%Y%m%d"

    # nephin
    nephin_line = JourneyPlanner.new.search(date, "Ballina", "Westport")
    nephin_line.trains_out.each do |trip|
      extract_trip_durations(trip, nephin_line.stations)
    end
    nephin_line.trains_ret.each do |trip|
      extract_trip_durations(trip, nephin_line.stations)
    end

    # covey
    covey_line = JourneyPlanner.new.search(date, "Westport", "Ballyhaunis")
    covey_line.trains_out.each do |trip|
      extract_trip_durations(trip, covey_line.stations)
    end
    covey_line.trains_ret.each do |trip|
      extract_trip_durations(trip, covey_line.stations)
    end

    # write config
    File.open('config.yaml', 'w') do |file|
      file.write(@stop_info.to_h.to_yaml)
    end
  end

  def rows
    results = []
    # find route group from search terms: nephin, covey, costello
    routes, _stops = find_route(@from, @to)
    # seach can return multiple routes
    routes.each do |route|
      # group by group trip ids
      rows = @train_trips.reject { |t| t.send("#{route}_id").nil? }.group_by(&:"#{route}_id").map do |trip_id, trains|
        # make this a hash instead, hashes are sorted in ruby so this will work
        stops = trains.flat_map { |train| train.stops }.sort_by { |stop| stop[1] }.each_with_object({}) { |i, obj| obj[i[0]] = i[1] } # join all stops and sort by time
        # filter by @from @to and add other tt info
        next unless stops[@from] && stops[@to]
        next unless stops[@from] < stops[@to]
        # return train result for tt
        [@from, @to, stops[@from].strftime("%H:%M"), stops[@to].strftime("%H:%M"), trains.map(&:info).join('; '), trains.first.send("#{route}_id")]
      end.compact
      # search will return dups for certain sections, uniuque
      rows.each { |row| results << row unless results.any? { |res| res[2..3] == row[2..3] } }
    end
    results
  end

  def as_ascii
    headers = %w[from to dep arr info trip_id]
    sort = headers.index(@sort)
    puts Terminal::Table.new rows: rows.sort_by { |r| r[sort] }, headings: headers, title: 'An Maightró', style: { all_separators: true }
  end

  def as_json
    File.open('dispatch.json', 'w') do |file|
      file.write(rows).sort_by(&:dep).map { |t| t.to_h.to_json }
    end
  end

  def run_analysis
    results = []
    stations = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]
    stations.each do |from|
      stations.each do |to|
        if from == to
          rows << [from, to, "n/a", "n/a", "n/a"]
          next
        end

        @from = from
        @to = to
        durations = rows.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }
        wtt = durations.max.round
        mtt = durations.sum(0.0).fdiv(durations.size).round
        nts = rows.count
        results << [@from, @to, wtt, mtt, nts]
      end
    end
    headers = %w[from to wtt mtt nts]
    title = "Analysis " + self.class.name
    puts Terminal::Table.new rows: results, headings: headers, title: title, style: { all_separators: true }
  end

  private

  def extract_trip_durations(trip, stations)
    trip.dig('secL').each do |t|
      t.dig('jny', 'stopL').each_cons(2) do |start, finish|
        next unless  finish['aTimeS'] && start["dTimeS"]

        dur = parse_time(finish['aTimeS']) - parse_time(start["dTimeS"])
        x = @stop_info[find_station(start, stations)] ||= {}
        y = x[find_station(finish, stations)] ||= nil
        x[find_station(finish, stations)] = dur if (y.nil? || dur < y)
      end
    end
  end
end

BaseOption.new.generate_configuration if __FILE__ == $PROGRAM_NAME
