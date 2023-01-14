# frozen_string_literal: true

require 'active_support/concern'
require 'time'

module Helper
  extend ActiveSupport::Concern

  def parse_time(time_str = '20221222')
    return unless time_str

    Time.parse(time_str[0..3].insert(2, ':'))
  end

  def find_station(current, stations)
    index = current['locX']
    stations.dig(index, 'name')
  end

  def distance_in_mins(dep, arr)
    (Time.parse(arr) - Time.parse(dep)).fdiv(60)
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
    def parse_time(time_str = '20221222')
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
