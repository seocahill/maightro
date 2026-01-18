# frozen_string_literal: true

require_relative "../domain"

module Maightro
  module Models
    # Collection of TrainPaths representing a day's timetable.
    # Provides query methods for finding connections and generating rows.
    #
    # @example
    #   timetable = Timetable.new(train_paths)
    #   timetable.journeys_between("Ballina", "Westport")
    #   timetable.rows("Foxford", "Castlebar")
    #
    class Timetable
      include Enumerable

      attr_reader :train_paths, :fare_calculator

      def initialize(train_paths, fare_calculator: nil)
        @train_paths = train_paths
        @fare_calculator = fare_calculator || default_fare_calculator
      end

      # Enumerable support
      def each(&block)
        @train_paths.each(&block)
      end

      def size
        @train_paths.size
      end

      def empty?
        @train_paths.empty?
      end

      # Find all journeys between two stations
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [Array<Hash>] journey details
      def journeys_between(from, to)
        routes = Domain::Route.connecting(from, to)
        results = []

        routes.each do |route|
          route_attr = route.path_attribute

          # Group trains by trip ID on this route
          grouped = @train_paths
                    .reject { |t| t.send(route_attr).nil? }
                    .group_by { |t| t.send(route_attr) }

          grouped.each do |trip_id, trains|
            journey = build_journey(trains, from, to, trip_id, route)
            results << journey if journey
          end
        end

        # Remove duplicates (same dep/arr times)
        results.uniq { |j| [j[:dep_time], j[:arr_time]] }
               .sort_by { |j| j[:dep_time] }
      end

      # Generate timetable rows (backwards compatible with BaseOption#rows)
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [Array<Array>] rows for display
      def rows(from, to)
        journeys_between(from, to).map do |j|
          [
            j[:from],
            j[:to],
            j[:dep_time],
            j[:arr_time],
            j[:fare],
            j[:duration],
            j[:info],
            j[:trip_id]
          ]
        end
      end

      # All trains on a specific route
      # @param route [Symbol, Domain::Route] route identifier
      # @return [Array<TrainPath>]
      def trains_on_route(route)
        route = Domain::Route[route] if route.is_a?(Symbol)
        route_attr = route.path_attribute

        @train_paths.reject { |t| t.send(route_attr).nil? }
      end

      # Find trains at a station within a time window
      # @param station [String] station name
      # @param after [Time] start of window
      # @param before [Time] end of window
      # @return [Array<TrainPath>]
      def trains_at(station, after: nil, before: nil)
        @train_paths.select do |train|
          stop = train.stops.find { |s| s[0] == station }
          next false unless stop

          time = stop[1]
          (after.nil? || time >= after) && (before.nil? || time <= before)
        end
      end

      # Add a train path
      # @param train_path [TrainPath]
      # @return [self]
      def <<(train_path)
        @train_paths << train_path
        self
      end

      # Combine with another timetable
      # @param other [Timetable]
      # @return [Timetable]
      def +(other)
        self.class.new(@train_paths + other.train_paths, fare_calculator: @fare_calculator)
      end

      private

      def build_journey(trains, from, to, trip_id, route)
        # Combine all stops from trains in this trip
        all_stops = trains
                    .flat_map(&:stops)
                    .sort_by { |s| s[1] }
                    .each_with_object({}) { |s, h| h[s[0]] = s[1] }

        # Must have both stations
        return nil unless all_stops[from] && all_stops[to]
        return nil unless all_stops[from] < all_stops[to]

        dep_time = all_stops[from]
        arr_time = all_stops[to]
        duration_mins = ((arr_time - dep_time) / 60).round

        {
          from: from,
          to: to,
          dep_time: dep_time.strftime("%H:%M"),
          arr_time: arr_time.strftime("%H:%M"),
          fare: @fare_calculator.formatted_fare(from, to),
          duration: "#{duration_mins} mins",
          info: trains.map(&:info).compact.join("; "),
          trip_id: trip_id,
          route: route.name
        }
      end

      def default_fare_calculator
        require_relative "../services/fare_calculator"
        Services::FareCalculator.default
      end
    end
  end
end
