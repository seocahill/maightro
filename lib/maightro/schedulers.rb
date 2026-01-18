# frozen_string_literal: true

require_relative "schedulers/base_scheduler"
require_relative "schedulers/optimized_scheduler"

module Maightro
  module Schedulers
    # Factory method for creating schedulers
    # @param name [Symbol] scheduler name (:status_quo, :optimized, :direct, :extended)
    # @param options [Hash] scheduler options
    # @return [BaseScheduler]
    def self.create(name, **options)
      case name.to_sym
      when :optimized, :option_1a
        OptimizedScheduler.new(**options)
      else
        raise ArgumentError, "Unknown scheduler: #{name}"
      end
    end
  end
end
