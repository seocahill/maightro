# frozen_string_literal: true

require_relative "../domain"

module Maightro
  module Services
    # Builds TrainPath objects with proper route assignment.
    # Encapsulates the complexity of creating train paths and assigning
    # them to the correct routes.
    #
    # @example
    #   builder = TrainPathBuilder.new(network: network, constraints: constraints)
    #
    #   # Build a local train
    #   path = builder.local_train(
    #     from: "Ballina",
    #     to: "Westport",
    #     departure: Time.parse("08:00"),
    #     trip_id: "LDT-1"
    #   )
    #
    #   # Build a connecting train (to meet mainline service)
    #   path = builder.connecting_train(
    #     from: "Ballina",
    #     to: "Manulla Junction",
    #     arrival: connection_time - crossover,
    #     connects_to: mainline_train
    #   )
    #
    class TrainPathBuilder
      attr_reader :network, :constraints

      def initialize(network: nil, constraints: nil)
        @network = network || Domain::Network.default
        @constraints = constraints || Domain::Constraints.default
      end

      # Build a local train (full journey, not connecting to mainline)
      # @param from [String] origin station
      # @param to [String] destination station
      # @param departure [Time] departure time
      # @param trip_id [String] trip identifier
      # @param info [String] optional info
      # @return [TrainPath]
      def local_train(from:, to:, departure:, trip_id:, info: "local")
        stops = @network.stops(from, to, departure)
        arrival = stops.last[1]

        build_path(
          from: from,
          to: to,
          departure: departure,
          arrival: arrival,
          stops: stops,
          trip_id: trip_id,
          direction: "local",
          info: info,
          position: to
        )
      end

      # Build a train to connect with mainline service
      # @param from [String] origin station
      # @param to [String] destination (usually Manulla Junction)
      # @param arrival [Time] required arrival time
      # @param trip_id [String] trip identifier
      # @param connects_to [TrainPath, nil] the mainline train being connected to
      # @param info [String] optional info
      # @return [TrainPath]
      def connecting_train(from:, to:, arrival:, trip_id:, connects_to: nil, info: nil)
        duration = @network.duration(from, to)
        departure = arrival - duration.seconds
        stops = @network.stops(from, to, departure)

        info ||= connects_to ? "To #{connects_to.direction}" : "connecting"

        build_path(
          from: from,
          to: to,
          departure: departure,
          arrival: arrival,
          stops: stops,
          trip_id: trip_id,
          direction: info,
          info: info,
          position: to,
          connection: connects_to&.trip_id
        )
      end

      # Build a train departing from junction after connection
      # @param to [String] destination station
      # @param departure [Time] departure time (after dwell/crossover)
      # @param trip_id [String] trip identifier
      # @param connects_from [TrainPath, nil] the mainline train connected from
      # @param info [String] optional info
      # @return [TrainPath]
      def from_junction(to:, departure:, trip_id:, connects_from: nil, info: nil)
        from = "Manulla Junction"
        stops = @network.stops(from, to, departure)
        arrival = stops.last[1]

        info ||= connects_from ? "From #{connects_from.direction}" : "local"

        build_path(
          from: from,
          to: to,
          departure: departure,
          arrival: arrival,
          stops: stops,
          trip_id: trip_id,
          direction: info,
          info: info,
          position: to,
          connection: connects_from&.trip_id
        )
      end

      # Calculate arrival time at junction for a train departing from station
      # @param from [String] origin station
      # @param departure [Time] departure time
      # @return [Time] arrival at Manulla Junction
      def junction_arrival(from:, departure:)
        departure + @network.duration(from, "Manulla Junction").seconds
      end

      # Calculate required departure to arrive at junction by specified time
      # @param from [String] origin station
      # @param junction_time [Time] required arrival at junction
      # @return [Time] required departure time
      def departure_for_junction(from:, junction_time:)
        junction_time - @network.duration(from, "Manulla Junction").seconds
      end

      private

      def build_path(from:, to:, departure:, arrival:, stops:, trip_id:, direction:, info:, position:, connection: nil)
        path = SimplePath.new(
          from: from,
          to: to,
          dep: departure,
          arr: arrival,
          stops: stops,
          trip_id: trip_id,
          dir: direction,
          info: info,
          position: position,
          connection: connection
        )

        # Assign to applicable routes
        assign_routes(path, from, to, trip_id)

        path
      end

      def assign_routes(path, from, to, trip_id)
        Domain::Route.connecting(from, to).each do |route|
          path.send("#{route.path_attribute}=", trip_id)
        end
      end

      # Simple path structure that doesn't require ActiveModel
      # Compatible with legacy TrainPath interface
      class SimplePath
        ROUTE_ATTRS = %i[nephin_id nephin_return_id covey_id covey_return_id costello_id costello_return_id].freeze

        attr_accessor :from, :to, :dep, :arr, :stops, :trip_id, :dir, :info, :position, :connection, :dwell
        attr_accessor(*ROUTE_ATTRS)

        def initialize(from:, to:, dep:, arr:, stops:, trip_id:, dir:, info:, position:, connection: nil, dwell: nil)
          @from = from
          @to = to
          @dep = dep
          @arr = arr
          @stops = stops
          @trip_id = trip_id
          @dir = dir
          @info = info
          @position = position
          @connection = connection
          @dwell = dwell

          ROUTE_ATTRS.each { |attr| instance_variable_set("@#{attr}", nil) }
        end

        def time_at_junction
          stops.find { |s| s[0] == "Manulla Junction" }&.dig(1)
        end

        def manulla_time
          from == "Manulla Junction" ? dep : arr
        end

        def arr_time
          arr.strftime("%H:%M")
        end

        def dep_time
          dep.strftime("%H:%M")
        end

        def direction
          dir
        end

        def attributes
          %i[from to dep arr dwell info trip_id dir position stops connection] + ROUTE_ATTRS
        end

        def values
          attributes.map { |attr| send(attr) }
        end
      end
    end
  end
end
