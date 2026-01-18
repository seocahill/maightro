# frozen_string_literal: true

require_relative "maightro/domain"
require_relative "maightro/models/train_path"
require_relative "maightro/models/timetable"
require_relative "maightro/services/fare_calculator"
require_relative "maightro/services/timetable_analyzer"
require_relative "maightro/services/train_path_builder"
require_relative "maightro/services/journey_planner"
require_relative "maightro/schedulers"

module Maightro
  class << self
    def network
      Domain::Network.default
    end

    def constraints
      Domain::Constraints.default
    end

    def fare_calculator
      Services::FareCalculator.default
    end

    def root
      File.expand_path("..", __dir__)
    end
  end
end
