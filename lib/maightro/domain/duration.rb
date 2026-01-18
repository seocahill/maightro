# frozen_string_literal: true

module Maightro
  module Domain
    # Value object representing a time duration.
    # Supports arithmetic operations and comparison.
    # Internally stores seconds for precision.
    #
    # @example
    #   dwell = Duration.minutes(3)
    #   travel = Duration.seconds(660)
    #   total = dwell + travel
    #   total.to_minutes # => 14.0
    #
    class Duration
      include Comparable

      class << self
        def seconds(value)
          new(value.to_f)
        end

        def minutes(value)
          new(value.to_f * 60)
        end

        def zero
          new(0)
        end
      end

      attr_reader :seconds

      def initialize(seconds)
        @seconds = seconds.to_f
        freeze
      end

      # Arithmetic operations
      def +(other)
        case other
        when Duration then self.class.new(@seconds + other.seconds)
        when Numeric then self.class.new(@seconds + other)
        else raise TypeError, "Cannot add #{other.class} to Duration"
        end
      end

      def -(other)
        case other
        when Duration then self.class.new(@seconds - other.seconds)
        when Numeric then self.class.new(@seconds - other)
        else raise TypeError, "Cannot subtract #{other.class} from Duration"
        end
      end

      def *(factor)
        self.class.new(@seconds * factor)
      end

      def /(divisor)
        self.class.new(@seconds / divisor)
      end

      def -@
        self.class.new(-@seconds)
      end

      # Comparison
      def <=>(other)
        case other
        when Duration then @seconds <=> other.seconds
        when Numeric then @seconds <=> other
        else nil
        end
      end

      def zero?
        @seconds.zero?
      end

      def positive?
        @seconds.positive?
      end

      def negative?
        @seconds.negative?
      end

      # Conversions
      def to_minutes
        @seconds / 60.0
      end

      def to_hours
        @seconds / 3600.0
      end

      def to_i
        @seconds.to_i
      end

      def to_f
        @seconds
      end

      # For adding to Time objects
      def coerce(other)
        case other
        when Numeric then [other, @seconds]
        else raise TypeError, "Cannot coerce #{other.class} with Duration"
        end
      end

      def to_s
        mins = to_minutes.round
        if mins >= 60
          hours = mins / 60
          remaining = mins % 60
          "#{hours}h #{remaining}m"
        else
          "#{mins} mins"
        end
      end

      def inspect
        "#<Duration #{to_s}>"
      end

      def hash
        @seconds.hash
      end

      def eql?(other)
        self == other
      end
    end
  end
end
