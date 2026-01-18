# frozen_string_literal: true

require_relative "base_scheduler"

module Maightro
  module Schedulers
    # Status quo scheduler (equivalent to Option1).
    #
    # Strategy: Simply import real Irish Rail timetable data.
    # No optimization or additions - this represents current service.
    #
    # @example
    #   scheduler = StatusQuoScheduler.new(date: "20231201")
    #   timetable = scheduler.run
    #
    class StatusQuoScheduler < BaseScheduler
      def schedule
        nephin = import_mainline_trains("Ballina", "Westport")
        covey = import_mainline_trains("Westport", "Ballyhaunis")
        costello = import_mainline_trains("Ballyhaunis", "Ballina")

        nephin + covey + costello
      end
    end
  end
end
