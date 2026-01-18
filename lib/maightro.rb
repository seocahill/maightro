# frozen_string_literal: true

require_relative "maightro/domain"
require_relative "maightro/models/train_path"

module Maightro
  class << self
    def network
      Domain::Network.default
    end

    def constraints
      Domain::Constraints.default
    end

    def root
      File.expand_path("..", __dir__)
    end
  end
end
