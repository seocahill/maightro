# frozen_string_literal: true

require_relative "../domain"
require_relative "../services/train_path_builder"
require_relative "../services/fare_calculator"
require_relative "../services/journey_planner"
require_relative "../models/timetable"

module Maightro
  module Schedulers
    # Base class for train scheduling algorithms.
    # Provides common infrastructure for all scenarios.
    #
    # Template Method pattern: subclasses implement #schedule
    # to define their scheduling algorithm.
    #
    # @example
    #   class OptimizedScheduler < BaseScheduler
    #     def schedule
    #       # Build train paths and return them
    #       [train1, train2, ...]
    #     end
    #   end
    #
    #   scheduler = OptimizedScheduler.new(date: "20231201")
    #   timetable = scheduler.run
    #   timetable.journeys_between("Ballina", "Westport")
    #
    class BaseScheduler
      attr_reader :date, :network, :constraints, :builder, :mainline_trains

      def initialize(date: nil, network: nil, constraints: nil)
        @date = date || default_date
        @network = network || Domain::Network.default
        @constraints = constraints || Domain::Constraints.default
        @builder = Services::TrainPathBuilder.new(network: @network, constraints: @constraints)
        @mainline_trains = []
        @journey_planner = Services::JourneyPlanner.new
      end

      # Run the scheduling algorithm
      # @return [Models::Timetable]
      def run
        train_paths = schedule
        Models::Timetable.new(train_paths)
      end

      # Override in subclass to implement scheduling algorithm
      # @return [Array<TrainPath>]
      def schedule
        raise NotImplementedError, "#{self.class} must implement #schedule"
      end

      protected

      # Import mainline trains from Irish Rail API
      # @param from [String] origin (e.g., "Ballyhaunis")
      # @param to [String] destination (e.g., "Westport")
      # @return [Array<TrainPath>] imported trains
      def import_mainline_trains(from, to)
        results = @journey_planner.search(@date, from, to)

        trains = []
        results.trains_out&.each { |trip| trains.concat(parse_trip(trip, results.stations, from, to)) }
        results.trains_ret&.each { |trip| trains.concat(parse_trip(trip, results.stations, to, from)) }

        @mainline_trains.concat(trains)
        trains
      end

      # Trains with a junction stop (needed for connections)
      # @return [Array<TrainPath>]
      def trains_at_junction
        @mainline_trains.select(&:time_at_junction)
      end

      # Next mainline train after given time
      # @param after [Time]
      # @return [TrainPath, nil]
      def next_mainline_after(after)
        trains_at_junction
          .select { |t| t.time_at_junction > after }
          .min_by(&:time_at_junction)
      end

      # Duration helpers (delegate to network)
      def duration(from, to)
        @network.duration(from, to)
      end

      def dwell
        @constraints.dwell
      end

      def turnaround
        @constraints.turnaround
      end

      def crossover
        @constraints.crossover
      end

      private

      def default_date
        # Last Thursday (for consistent VCR cassettes)
        today = Date.today
        last_thursday = today - ((today.wday - 4) % 7)
        last_thursday.strftime("%Y%m%d")
      end

      def parse_trip(trip, stations, from, to)
        Services::TrainDataParser.parse_trip(trip, stations, from, to)
      end
    end
  end
end
