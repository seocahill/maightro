# frozen_string_literal: true

module Maightro
  module Domain
    # Value object representing a station on the Mayo rail network.
    # Immutable, comparable, and provides identity semantics.
    #
    # @example
    #   ballina = Station[:ballina]
    #   westport = Station[:westport]
    #   ballina == Station.new("Ballina") # => true
    #
    class Station
      include Comparable

      STATIONS = {
        ballina: "Ballina",
        foxford: "Foxford",
        manulla: "Manulla Junction",
        castlebar: "Castlebar",
        westport: "Westport",
        claremorris: "Claremorris",
        ballyhaunis: "Ballyhaunis"
      }.freeze

      ALIASES = {
        "Manulla Junction" => :manulla,
        "Manulla" => :manulla
      }.freeze

      class << self
        # Factory method using symbol lookup
        # @param key [Symbol] station identifier
        # @return [Station]
        def [](key)
          name = STATIONS.fetch(key) { raise ArgumentError, "Unknown station: #{key}" }
          new(name)
        end

        # All stations on the network
        # @return [Array<Station>]
        def all
          STATIONS.keys.map { |key| self[key] }
        end

        # Passenger stations (excludes Manulla Junction which is interchange only)
        # @return [Array<Station>]
        def passenger_stations
          all.reject(&:junction?)
        end
      end

      attr_reader :name

      def initialize(name)
        @name = normalize(name)
        freeze
      end

      def to_s
        @name
      end

      def to_sym
        ALIASES[@name] || @name.downcase.gsub(/\s+/, "_").to_sym
      end

      def junction?
        @name == "Manulla Junction"
      end

      def <=>(other)
        return nil unless other.is_a?(Station)

        name <=> other.name
      end

      def hash
        @name.hash
      end

      def eql?(other)
        self == other
      end

      private

      def normalize(name)
        # Handle both symbol keys and string names
        return STATIONS[name] if name.is_a?(Symbol) && STATIONS.key?(name)

        name.to_s
      end
    end
  end
end
