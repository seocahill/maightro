# frozen_string_literal: true

module Maightro
  module Domain
    # Represents a directional rail route on the Mayo network.
    # Each physical line has two routes (outbound and return).
    #
    # The three physical lines meeting at Manulla Junction:
    # - Nephin Line: Ballina <-> Westport (via Foxford, Manulla, Castlebar)
    # - Covey Line: Westport <-> Ballyhaunis (via Castlebar, Manulla, Claremorris)
    # - Costello Line: Ballyhaunis <-> Ballina (via Claremorris, Manulla, Foxford)
    #
    # @example
    #   route = Route[:nephin]
    #   route.stops # => ["Ballina", "Foxford", "Manulla Junction", "Castlebar", "Westport"]
    #   route.includes?("Foxford", "Castlebar") # => true
    #   route.return # => Route[:nephin_return]
    #
    class Route
      DEFINITIONS = {
        nephin: %w[Ballina Foxford Manulla\ Junction Castlebar Westport],
        covey: %w[Westport Castlebar Manulla\ Junction Claremorris Ballyhaunis],
        costello: %w[Ballyhaunis Claremorris Manulla\ Junction Foxford Ballina]
      }.freeze

      class << self
        # Factory method
        # @param key [Symbol] route identifier (e.g., :nephin, :nephin_return)
        # @return [Route]
        def [](key)
          key = key.to_sym
          return @cache[key] if @cache&.key?(key)

          @cache ||= {}
          @cache[key] = build(key)
        end

        # All defined routes (including returns)
        # @return [Array<Route>]
        def all
          DEFINITIONS.keys.flat_map { |k| [self[k], self[:"#{k}_return"]] }
        end

        # Find routes that connect two stations
        # @param from [String, Station] origin station
        # @param to [String, Station] destination station
        # @return [Array<Route>] matching routes
        def connecting(from, to)
          from_name = from.respond_to?(:name) ? from.name : from.to_s
          to_name = to.respond_to?(:name) ? to.name : to.to_s

          all.select { |route| route.connects?(from_name, to_name) }
        end

        private

        def build(key)
          base_key = key.to_s.sub(/_return$/, "").to_sym
          stops = DEFINITIONS.fetch(base_key) { raise ArgumentError, "Unknown route: #{key}" }
          stops = stops.reverse if key.to_s.end_with?("_return")

          new(key, stops)
        end
      end

      attr_reader :name, :stops

      def initialize(name, stops)
        @name = name
        @stops = stops.freeze
        freeze
      end

      # Origin station
      def origin
        @stops.first
      end

      # Terminus station
      def terminus
        @stops.last
      end

      # Is this a return route?
      def return_route?
        @name.to_s.end_with?("_return")
      end

      # Get the opposite direction route
      def return
        if return_route?
          Route[@name.to_s.sub(/_return$/, "").to_sym]
        else
          Route[:"#{@name}_return"]
        end
      end

      # Base line name (without _return suffix)
      def line_name
        @name.to_s.sub(/_return$/, "").to_sym
      end

      # Check if route includes a station
      def includes?(station)
        station_name = station.respond_to?(:name) ? station.name : station.to_s
        @stops.include?(station_name)
      end

      # Check if route connects from -> to in that direction
      def connects?(from, to)
        from_idx = @stops.index(from.to_s)
        to_idx = @stops.index(to.to_s)

        from_idx && to_idx && from_idx < to_idx
      end

      # Get stops between two stations (inclusive)
      def stops_between(from, to)
        from_idx = @stops.index(from.to_s)
        to_idx = @stops.index(to.to_s)

        return [] unless from_idx && to_idx && from_idx <= to_idx

        @stops[from_idx..to_idx]
      end

      # Attribute ID for TrainPath (e.g., :nephin_id, :covey_return_id)
      def path_attribute
        :"#{@name}_id"
      end

      def to_s
        @name.to_s
      end

      def to_sym
        @name
      end

      def ==(other)
        other.is_a?(Route) && @name == other.name
      end

      alias eql? ==

      def hash
        @name.hash
      end

      def inspect
        "#<Route:#{@name} #{origin} -> #{terminus}>"
      end
    end
  end
end
