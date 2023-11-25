# frozen_string_literal: true

require 'active_support/concern'
require 'time'
require 'date'

module Helper
  extend ActiveSupport::Concern

  def parse_time(time_str = last_thursday)
    return unless time_str

    Time.parse(time_str[0..3].insert(2, ':'))
  end

  def last_thursday
    today = Date.today
    # Subtracting days from today until we get a Thursday (where day of the week is 4)
    last_thursday = today - ((today.wday - 4) % 7)
    last_thursday.strftime('%Y%m%d')
  end

  def find_station(current, stations)
    index = current['locX']
    stations.dig(index, 'name')
  end

  def distance_in_mins(dep, arr)
    arr_time = Time.parse(arr)
    dep_time = Time.parse(dep)
    # if less than earliest possible train, must be next day arrival
    arr_time += 86400 if arr_time < Time.parse("05:00")
    dep_time += 86400 if dep_time < Time.parse("05:00")
    (arr_time - dep_time).fdiv(60)
  end

  def find_route(from, to)
    base_routes = {
      nephin: ["Ballina", "Foxford", "Manulla Junction", "Castlebar", "Westport"],
      covey: ["Westport", "Castlebar", "Manulla Junction", "Claremorris", "Ballyhaunis"],
      costello: ["Ballyhaunis", "Claremorris", "Manulla Junction", "Foxford", "Ballina"]
    }

    # reverse, this way you get directional certainty which decomplicates things considerably
    routes = {}
    base_routes.each do |k,v|
      routes[k] = v
      routes["#{k}_return".to_sym] = v.reverse
    end

    matched_routes = []
    matched_stops = []

    routes.each do |(route, stops)|
      if sdx = stops.index(from)
        if edx = stops[(sdx + 1)..].index(to)
          matched_routes << route
          matched_stops += stops[sdx..(sdx + (edx + 1))]
        end
      end
    end
    [matched_routes.uniq, matched_stops.uniq]
  end

  def stops(from, to, dep)
    results = [[from, dep]]
    current = dep
    route, stops = find_route(from, to)
    stops.each_cons(2) do |f,t|
      next unless f && t

      # seems like dwell is included already
      current += @stop_info[f][t]
      results << [t, current]
    end
    results
  end

  def duration(from, to)
    _routes, stops = find_route(from, to)
    stops.each_cons(2).map do |f, t|
      @stop_info[f][t]
    end.sum
  end

  class_methods do
    def parse_time(time_str = last_thursday)
      return unless time_str

      Time.parse(time_str[0..3].insert(2, ':'))
    end

    def find_station(current, stations)
      index = current['locX']
      stations.dig(index, 'name')
    end

    def populate_stop_information(train, stations)
      train.dig('jny', 'stopL').map do |stop|
        name = find_station(stop, stations)
        # dep time except for last stop
        time = parse_time(stop["dTimeS"]) || parse_time(stop['aTimeS'])
        [name, time]
      end
    end
  end
end
