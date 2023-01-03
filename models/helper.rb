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

  def find_route(from, to)
    routes = {
      nephin: ["Ballina", "Foxford", "Manulla Junction", "Castlebar", "Westport"],
      covey: ["Westport", "Castlebar", "Manulla Junction", "Claremorris", "Ballyhaunis"],
      costello: ["Ballyhaunis", "Claremorris", "Manulla Junction", "Foxford", "Ballina"]
    }

    matched_routes = []
    matched_stops = []

    routes.each do |(route, stops)|
      # out
      if sdx = stops.index(from)
        if edx = stops[sdx..].index(to)
          matched_routes << route
          matched_stops += stops[sdx..(sdx + edx)]
        end
      end

      # back
      back = stops.reverse
      if sdx = back.index(from)
        if edx = back[sdx..].index(to)
          matched_routes << route
          matched_stops += back[sdx..(sdx + edx)]
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

      current += (@stop_info[f][t] + @dwell)
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
