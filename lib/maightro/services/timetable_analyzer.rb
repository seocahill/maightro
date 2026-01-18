# frozen_string_literal: true

require "csv"

module Maightro
  module Services
    # Analyzes timetables to produce service quality metrics.
    # Extracted from BaseOption#run_analysis.
    #
    # Metrics:
    # - N (nts): Number of trains per day
    # - W (wtt): Worst-case travel time (minutes)
    # - M (mtt): Mean travel time (minutes)
    # - F (fs): Frequency - average hours between trains
    #
    # @example
    #   analyzer = TimetableAnalyzer.new(option.rows)
    #   analyzer.analyze("Ballina", "Westport")
    #   # => { from: "Ballina", to: "Westport", n: 8, wtt: 65, mtt: 52, frequency: 2.1 }
    #
    class TimetableAnalyzer
      PASSENGER_STATIONS = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis].freeze

      Metrics = Struct.new(:from, :to, :train_count, :mean_time, :worst_time, :frequency, keyword_init: true) do
        def to_a
          [from, to, train_count, mean_time, worst_time, frequency]
        end

        def to_h
          {
            from: from,
            to: to,
            n: train_count,
            mtt: mean_time,
            wtt: worst_time,
            frequency: frequency
          }
        end
      end

      attr_reader :rows

      # @param rows [Array] timetable rows from option.rows
      def initialize(rows)
        @rows = rows
      end

      # Analyze a single station pair
      # @param from [String] origin station
      # @param to [String] destination station
      # @return [Metrics, nil]
      def analyze(from, to)
        relevant_rows = filter_rows(from, to)
        return nil if relevant_rows.empty?

        durations = relevant_rows.map { |r| distance_in_mins(r[2], r[3]) }
        departures = relevant_rows.map { |r| Time.parse(r[2]) }

        Metrics.new(
          from: from,
          to: to,
          train_count: relevant_rows.count,
          mean_time: mean(durations).round,
          worst_time: durations.max.round,
          frequency: calculate_frequency(departures)
        )
      end

      # Analyze all station pairs
      # @return [Array<Metrics>]
      def analyze_all
        results = []

        PASSENGER_STATIONS.each do |from|
          PASSENGER_STATIONS.each do |to|
            next if from == to

            metrics = analyze(from, to)
            results << metrics if metrics
          end
        end

        results
      end

      # Run full analysis returning raw arrays (for backwards compatibility)
      # @return [Array<Array>]
      def run_analysis
        analyze_all.map(&:to_a)
      end

      # Export to CSV
      # @param filename [String] output filename
      def to_csv(filename)
        headers = %w[from to nts mtt wtt fs]

        CSV.open(filename, "w", headers: true) do |csv|
          csv << headers
          analyze_all.each { |m| csv << m.to_a }
        end
      end

      private

      def filter_rows(from, to)
        @rows.select do |r|
          r[0] == from && r[1] == to
        end
      end

      def distance_in_mins(dep_str, arr_str)
        arr_time = Time.parse(arr_str)
        dep_time = Time.parse(dep_str)

        # Handle overnight journeys
        arr_time += 86_400 if arr_time < Time.parse("05:00")
        dep_time += 86_400 if dep_time < Time.parse("05:00")

        (arr_time - dep_time).fdiv(60)
      end

      def mean(values)
        return 0 if values.empty?

        values.sum(0.0) / values.size
      end

      def calculate_frequency(departures)
        return 0 if departures.size < 2

        first_dep, last_dep = departures.minmax
        span_hours = (last_dep - first_dep).fdiv(3600)
        (span_hours / departures.size).round(1)
      end
    end
  end
end
