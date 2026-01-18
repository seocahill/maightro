# frozen_string_literal: true

require "time"

require_relative "domain/duration"
require_relative "domain/station"
require_relative "domain/route"
require_relative "domain/constraints"
require_relative "domain/network"

module Maightro
  module Domain
    # Convenience method to access default network
    def self.network
      Network.default
    end

    # Convenience method to access default constraints
    def self.constraints
      Constraints.default
    end
  end
end
