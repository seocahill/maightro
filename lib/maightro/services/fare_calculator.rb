# frozen_string_literal: true

require "yaml"

module Maightro
  module Services
    # Handles fare lookups and formatting.
    # Extracted from BaseOption to follow Single Responsibility Principle.
    #
    # @example
    #   calculator = FareCalculator.new
    #   calculator.fare_range("Ballina", "Westport") # => [765, 765]
    #   calculator.formatted_fare("Ballina", "Westport") # => "€7.65"
    #
    class FareCalculator
      class << self
        def default
          @default ||= new
        end

        def reset!
          @default = nil
        end
      end

      def initialize(fares_path = "fares.yaml")
        @fares = YAML.load_file(fares_path)
      end

      # Get fare range in cents
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [Array<Integer>] [min_cents, max_cents]
      def fare_range(from, to)
        from_name = station_name(from)
        to_name = station_name(to)

        @fares.dig(from_name, to_name) || [0, 0]
      end

      # Get formatted fare string
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [String] formatted fare (e.g., "€7.65" or "€5.15 - 7.65")
      def formatted_fare(from, to)
        low, high = fare_range(from, to)
        return "N/A" if low.nil? || low.zero?

        low_eur = format_euros(low)
        high_eur = format_euros(high)

        low == high ? low_eur : "#{low_eur} - #{high_eur}"
      end

      # Check if fare exists for route
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [Boolean]
      def fare_exists?(from, to)
        low, = fare_range(from, to)
        !low.nil? && low.positive?
      end

      # All station pairs with fares
      # @return [Array<Array<String>>] [[from, to], ...]
      def all_routes
        @fares.flat_map do |from, destinations|
          destinations.keys.map { |to| [from, to] }
        end
      end

      private

      def station_name(station)
        station.respond_to?(:name) ? station.name : station.to_s
      end

      def format_euros(cents)
        "€#{cents.fdiv(100)}"
      end
    end
  end
end
