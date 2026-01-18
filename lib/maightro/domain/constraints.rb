# frozen_string_literal: true

module Maightro
  module Domain
    # Encapsulates scheduling constraints for train operations.
    # These represent physical and operational limits on train movements.
    #
    # @example
    #   constraints = Constraints.default
    #   constraints.dwell          # => Duration (3 minutes)
    #   constraints.turnaround     # => Duration (9 minutes)
    #   constraints.can_turn?(arrival_time, next_departure) # => true/false
    #
    class Constraints
      class << self
        # Default constraints based on current Mayo line operations
        def default
          new(
            dwell: Duration.minutes(3),
            turnaround: Duration.minutes(9),
            crossover: Duration.minutes(9),
            service_start: "05:00",
            service_end: "23:59"
          )
        end

        # Tighter constraints for testing optimization limits
        def minimum
          new(
            dwell: Duration.minutes(2),
            turnaround: Duration.minutes(6),
            crossover: Duration.minutes(6),
            service_start: "05:00",
            service_end: "23:59"
          )
        end
      end

      attr_reader :dwell, :turnaround, :crossover, :service_start, :service_end

      # @param dwell [Duration] minimum stop time at stations
      # @param turnaround [Duration] minimum time to reverse direction at terminus
      # @param crossover [Duration] minimum time for trains to cross at junction
      # @param service_start [String] earliest departure time (HH:MM)
      # @param service_end [String] latest arrival time (HH:MM)
      def initialize(dwell:, turnaround:, crossover:, service_start:, service_end:)
        @dwell = dwell
        @turnaround = turnaround
        @crossover = crossover
        @service_start = Time.parse(service_start)
        @service_end = Time.parse(service_end)
        freeze
      end

      # Check if a train can turn around between arrival and next departure
      # @param arrival [Time] when train arrives at terminus
      # @param next_departure [Time] when train needs to depart
      # @return [Boolean]
      def can_turn?(arrival, next_departure)
        (next_departure - arrival) >= @turnaround.seconds
      end

      # Check if trains can safely cross at junction
      # @param train1_time [Time] first train at junction
      # @param train2_time [Time] second train at junction
      # @return [Boolean]
      def can_cross?(train1_time, train2_time)
        (train2_time - train1_time).abs >= @crossover.seconds
      end

      # Calculate earliest departure after arrival (for turnaround)
      # @param arrival [Time] arrival time at terminus
      # @return [Time] earliest possible departure
      def earliest_departure_after(arrival)
        arrival + @turnaround.seconds
      end

      # Calculate earliest arrival allowing for crossover
      # @param junction_time [Time] when first train is at junction
      # @return [Time] earliest safe time for second train
      def earliest_crossing_after(junction_time)
        junction_time + @crossover.seconds
      end

      # Is the given time within service hours?
      # @param time [Time]
      # @return [Boolean]
      def within_service_hours?(time)
        time >= @service_start && time <= @service_end
      end

      # Duration as legacy float (for backwards compatibility)
      def dwell_seconds
        @dwell.seconds
      end

      def turnaround_seconds
        @turnaround.seconds
      end

      def crossover_seconds
        @crossover.seconds
      end

      def to_h
        {
          dwell: @dwell.to_minutes,
          turnaround: @turnaround.to_minutes,
          crossover: @crossover.to_minutes,
          service_start: @service_start.strftime("%H:%M"),
          service_end: @service_end.strftime("%H:%M")
        }
      end

      def inspect
        "#<Constraints dwell=#{@dwell} turnaround=#{@turnaround} crossover=#{@crossover}>"
      end
    end
  end
end
