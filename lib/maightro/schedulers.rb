# frozen_string_literal: true

require_relative "schedulers/base_scheduler"
require_relative "schedulers/status_quo_scheduler"
require_relative "schedulers/optimized_scheduler"
require_relative "schedulers/direct_scheduler"
require_relative "schedulers/extended_scheduler"

module Maightro
  module Schedulers
    # Mapping from legacy Option names to new schedulers
    LEGACY_MAPPING = {
      "Option1" => :status_quo,
      "Option1a" => :optimized,
      "Option2" => :direct,
      "Option3" => :extended,
      "Option3b" => :extended_ballyhaunis
    }.freeze

    # Factory method for creating schedulers
    # @param name [Symbol, String] scheduler name or legacy Option name
    # @param options [Hash] scheduler options
    # @return [BaseScheduler]
    def self.create(name, **options)
      # Handle legacy Option names
      name = LEGACY_MAPPING[name.to_s] || name.to_sym

      case name
      when :status_quo, :option1
        StatusQuoScheduler.new(**options)
      when :optimized, :option1a
        OptimizedScheduler.new(**options)
      when :direct, :option2
        DirectScheduler.new(**options)
      when :extended, :option3
        ExtendedScheduler.new(terminus: "Claremorris", **options)
      when :extended_ballyhaunis, :option3b
        ExtendedScheduler.new(terminus: "Ballyhaunis", **options)
      else
        raise ArgumentError, "Unknown scheduler: #{name}"
      end
    end

    # For backwards compatibility with app
    def self.for_option(option_name, date:, from: nil, to: nil)
      scheduler = create(option_name, date: date)
      timetable = scheduler.run

      # Return a wrapper that responds to .rows and .run_analysis
      SchedulerResult.new(timetable, from, to)
    end
  end

  # Wrapper class for backwards compatibility
  class SchedulerResult
    def initialize(timetable, from, to)
      @timetable = timetable
      @from = from || "Ballina"
      @to = to || "Westport"
    end

    def rows
      @timetable.rows(@from, @to)
    end

    def run_analysis
      all_rows = []
      stations = %w[Ballina Foxford Castlebar Westport Claremorris Ballyhaunis]

      stations.each do |from|
        stations.each do |to|
          next if from == to

          all_rows.concat(@timetable.rows(from, to))
        end
      end

      analyzer = Services::TimetableAnalyzer.new(all_rows)
      analyzer.run_analysis
    end
  end
end
