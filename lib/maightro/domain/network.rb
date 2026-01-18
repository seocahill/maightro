# frozen_string_literal: true

require "yaml"

module Maightro
  module Domain
    # Represents the Mayo rail network topology and travel times.
    # Encapsulates the knowledge previously spread across Helper module
    # and config.yaml loading.
    #
    # @example
    #   network = Network.load("config.yaml")
    #   network.duration("Ballina", "Manulla Junction") # => Duration
    #   network.routes_between("Foxford", "Castlebar")  # => [Route, ...]
    #   network.stops("Ballina", "Westport", Time.parse("08:00")) # => [[station, time], ...]
    #
    class Network
      class << self
        # Load network from config file
        # @param config_path [String] path to YAML config
        # @return [Network]
        def load(config_path = "config.yaml")
          travel_times = YAML.load_file(config_path)
          new(travel_times)
        end

        # Default network instance (singleton-ish for convenience)
        def default
          @default ||= load
        end

        def reset_default!
          @default = nil
        end
      end

      attr_reader :travel_times

      # @param travel_times [Hash] station -> station -> seconds
      def initialize(travel_times)
        @travel_times = travel_times.freeze
      end

      # Get travel duration between adjacent stations
      # @param from [String, Station] origin
      # @param to [String, Station] destination
      # @return [Duration]
      def segment_duration(from, to)
        from_name = station_name(from)
        to_name = station_name(to)

        seconds = @travel_times.dig(from_name, to_name)
        raise ArgumentError, "No travel time defined for #{from_name} -> #{to_name}" unless seconds

        Duration.seconds(seconds)
      end

      # Get total travel duration across a route
      # @param from [String, Station] origin
      # @param to [String, Station] destination
      # @return [Duration]
      def duration(from, to)
        stops = stops_on_route(from, to)
        return Duration.zero if stops.size < 2

        stops.each_cons(2).sum(Duration.zero) do |f, t|
          segment_duration(f, t)
        end
      end

      # Find routes connecting two stations
      # @param from [String, Station] origin
      # @param to [String, Station] destination
      # @return [Array<Route>]
      def routes_between(from, to)
        Route.connecting(from, to)
      end

      # Get station sequence on a route
      # @param from [String, Station] origin
      # @param to [String, Station] destination
      # @return [Array<String>] station names
      def stops_on_route(from, to)
        routes = routes_between(from, to)
        return [] if routes.empty?

        # Use first matching route
        routes.first.stops_between(from, to)
      end

      # Calculate stops with arrival times
      # @param from [String, Station] origin
      # @param to [String, Station] destination
      # @param departure [Time] departure time from origin
      # @return [Array<Array(String, Time)>] [[station, time], ...]
      def stops(from, to, departure)
        from_name = station_name(from)
        to_name = station_name(to)
        stop_list = stops_on_route(from_name, to_name)

        return [] if stop_list.empty?

        current_time = departure
        result = [[from_name, current_time]]

        stop_list.each_cons(2) do |f, t|
          current_time += segment_duration(f, t).seconds
          result << [t, current_time]
        end

        result
      end

      # Check if two stations are directly connected (adjacent)
      # @param from [String, Station]
      # @param to [String, Station]
      # @return [Boolean]
      def adjacent?(from, to)
        from_name = station_name(from)
        to_name = station_name(to)

        @travel_times.dig(from_name, to_name).present? ||
          @travel_times.dig(to_name, from_name).present?
      end

      # All stations in the network
      # @return [Array<String>]
      def stations
        @travel_times.keys
      end

      private

      def station_name(station)
        station.respond_to?(:name) ? station.name : station.to_s
      end
    end
  end
end
