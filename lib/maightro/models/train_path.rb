# frozen_string_literal: true

require_relative "../domain"

module Maightro
  module Models
    # Represents a single train movement from one station to another.
    # This is the core scheduling unit - trains are composed of one or more paths.
    #
    # Improvements over original:
    # - Route assignment is encapsulated (no more external `send("#{route}_id=", ...)`)
    # - Uses Duration value objects
    # - Immutable where possible
    # - Builder pattern for construction
    #
    # @example
    #   path = TrainPath.build do |b|
    #     b.from = "Ballina"
    #     b.to = "Manulla Junction"
    #     b.departure = Time.parse("08:00")
    #     b.trip_id = "LC-1"
    #   end
    #
    #   path.duration          # => Duration
    #   path.assign_to_route(:nephin)
    #   path.on_route?(:nephin) # => true
    #
    class TrainPath
      # Builder for fluent construction
      class Builder
        attr_accessor :from, :to, :departure, :arrival, :trip_id, :direction,
                      :info, :position, :stops, :connection

        def initialize(network: Domain.network)
          @network = network
          @stops = []
        end

        def build
          validate!
          calculate_derived_values!

          TrainPath.new(
            from: @from,
            to: @to,
            departure: @departure,
            arrival: @arrival,
            trip_id: @trip_id,
            direction: @direction,
            info: @info,
            position: @position || @to,
            stops: @stops,
            connection: @connection
          )
        end

        private

        def validate!
          raise ArgumentError, "from is required" unless @from
          raise ArgumentError, "to is required" unless @to
          raise ArgumentError, "departure is required" unless @departure
        end

        def calculate_derived_values!
          # Calculate stops if not provided
          if @stops.empty?
            @stops = @network.stops(@from, @to, @departure)
          end

          # Calculate arrival if not provided
          @arrival ||= @stops.last&.dig(1) || (@departure + @network.duration(@from, @to).seconds)
        end
      end

      class << self
        def build(network: Domain.network, &block)
          builder = Builder.new(network: network)
          yield builder
          builder.build
        end

        # Factory from Irish Rail API response (backwards compatible)
        def from_api_response(train, trip, stations)
          from = find_station(train["dep"], stations)
          to = find_station(train["arr"], stations)
          dep = parse_time(train["dep"]["dTimeS"])
          arr = parse_time(train["arr"]["aTimeS"])
          stops = populate_stops(train, stations)
          dir = train.dig("jny", "dirTxt")

          path = new(
            from: from,
            to: to,
            departure: dep,
            arrival: arr,
            direction: dir,
            info: "to #{dir}",
            trip_id: trip["cid"],
            stops: stops
          )

          # Assign to applicable routes
          path.assign_routes_for_journey(stops.first[0], stops.last[0])

          path
        end

        private

        def find_station(loc_data, stations)
          index = loc_data["locX"]
          stations.dig(index, "name")
        end

        def parse_time(time_str)
          return nil unless time_str

          Time.parse(time_str[0..3].insert(2, ":"))
        end

        def populate_stops(train, stations)
          train.dig("jny", "stopL").map do |stop|
            name = find_station(stop, stations)
            time = parse_time(stop["dTimeS"]) || parse_time(stop["aTimeS"])
            [name, time]
          end
        end
      end

      # Route ID attributes
      ROUTE_ATTRIBUTES = %i[
        nephin_id nephin_return_id
        covey_id covey_return_id
        costello_id costello_return_id
      ].freeze

      attr_reader :from, :to, :departure, :arrival, :trip_id, :direction,
                  :info, :position, :stops, :connection, :dwell

      attr_accessor(*ROUTE_ATTRIBUTES)

      # For backwards compatibility with existing code
      alias dep departure
      alias arr arrival
      alias dir direction

      def initialize(from:, to:, departure:, arrival:, trip_id: nil, direction: nil,
                     info: nil, position: nil, stops: [], connection: nil, dwell: nil)
        @from = from
        @to = to
        @departure = departure
        @arrival = arrival
        @trip_id = trip_id
        @direction = direction
        @info = info
        @position = position || to
        @stops = stops
        @connection = connection
        @dwell = dwell

        # Initialize route IDs to nil
        ROUTE_ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", nil) }
      end

      # Duration of this path
      # @return [Domain::Duration]
      def duration
        Domain::Duration.seconds(@arrival - @departure)
      end

      # Time at Manulla Junction (if on route)
      # @return [Time, nil]
      def time_at_junction
        junction_stop = @stops.find { |s| s[0] == "Manulla Junction" }
        junction_stop&.dig(1)
      end

      # Manulla time based on direction
      def manulla_time
        if @from == "Manulla Junction"
          @departure
        else
          @arrival
        end
      end

      # Formatted times
      def dep_time
        @departure.strftime("%H:%M")
      end

      def arr_time
        @arrival.strftime("%H:%M")
      end

      # Assign this path to a specific route
      # @param route [Symbol, Domain::Route] route identifier
      # @param id [String] trip identifier to assign
      def assign_to_route(route, id = @trip_id)
        route = Domain::Route[route] if route.is_a?(Symbol)
        attr = route.path_attribute

        send("#{attr}=", id) if respond_to?("#{attr}=")
      end

      # Assign to all applicable routes for a journey
      # @param journey_from [String] journey origin
      # @param journey_to [String] journey destination
      def assign_routes_for_journey(journey_from, journey_to)
        Domain::Route.connecting(journey_from, journey_to).each do |route|
          assign_to_route(route)
        end
      end

      # Check if path is assigned to a route
      # @param route [Symbol] route identifier
      # @return [Boolean]
      def on_route?(route)
        route = Domain::Route[route] if route.is_a?(Symbol)
        !send(route.path_attribute).nil?
      end

      # All routes this path is assigned to
      # @return [Array<Symbol>]
      def assigned_routes
        ROUTE_ATTRIBUTES.select { |attr| !send(attr).nil? }
                        .map { |attr| attr.to_s.sub(/_id$/, "").to_sym }
      end

      # Legacy compatibility: attribute list
      def attributes
        %i[from to dep arr dwell info trip_id dir position stops connection] + ROUTE_ATTRIBUTES
      end

      def values
        attributes.map { |attr| send(attr) }
      end

      # Create a copy with modifications
      def with(**changes)
        attrs = {
          from: @from, to: @to, departure: @departure, arrival: @arrival,
          trip_id: @trip_id, direction: @direction, info: @info,
          position: @position, stops: @stops.dup, connection: @connection, dwell: @dwell
        }.merge(changes)

        self.class.new(**attrs).tap do |new_path|
          ROUTE_ATTRIBUTES.each do |attr|
            new_path.send("#{attr}=", send(attr))
          end
        end
      end

      # Shift all times by an offset
      # @param offset [Numeric, Duration] seconds to shift
      # @return [TrainPath] new path with shifted times
      def shift_times(offset)
        offset_seconds = offset.respond_to?(:seconds) ? offset.seconds : offset

        with(
          departure: @departure + offset_seconds,
          arrival: @arrival + offset_seconds,
          stops: @stops.map { |name, time| [name, time + offset_seconds] },
          info: "shifted by #{(offset_seconds / 60).round} mins"
        )
      end

      def inspect
        "#<TrainPath #{@from}->#{@to} dep=#{dep_time} arr=#{arr_time} trip=#{@trip_id}>"
      end
    end
  end
end
