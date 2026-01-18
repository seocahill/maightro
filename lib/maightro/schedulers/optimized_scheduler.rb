# frozen_string_literal: true

require_relative "base_scheduler"

module Maightro
  module Schedulers
    # Optimized scheduling algorithm (equivalent to Option1a).
    #
    # Strategy: Take real Dublin-Westport mainline trains and create
    # connecting Ballina trains that meet each one at Manulla Junction.
    #
    # Algorithm:
    # 1. Import mainline trains (Dublin <-> Westport via Manulla)
    # 2. For each mainline train stopping at Manulla Junction:
    #    - Calculate when Ballina train must depart to arrive in time
    #    - Create up train (Ballina -> Manulla) arriving before mainline
    #    - Create down train (Manulla -> Ballina) departing after mainline
    # 3. Fix any timing conflicts between consecutive trains
    #
    # @example
    #   scheduler = OptimizedScheduler.new(date: "20231201")
    #   timetable = scheduler.run
    #
    class OptimizedScheduler < BaseScheduler
      def schedule
        import_mainline_trains("Ballyhaunis", "Westport")
        ballina_trains = create_connecting_trains
        fix_overlapping_trains(ballina_trains)

        ballina_trains + @mainline_trains
      end

      private

      def create_connecting_trains
        trains = []

        trains_at_junction.each do |mainline|
          up_train = create_up_train(mainline)
          down_train = create_down_train(mainline)

          trains << up_train << down_train
        end

        trains
      end

      # Train from Ballina to Manulla Junction (to meet mainline)
      def create_up_train(mainline)
        junction_time = mainline.time_at_junction
        branch_duration = duration("Ballina", "Manulla Junction")

        # Must arrive before mainline, with dwell time for connection
        arrival = junction_time - crossover.seconds
        departure = arrival - branch_duration.seconds

        train = @builder.connecting_train(
          from: "Ballina",
          to: "Manulla Junction",
          arrival: arrival,
          trip_id: mainline.trip_id,
          connects_to: mainline,
          info: "To #{mainline.dir}"
        )

        # Assign to routes connecting Ballina to mainline destination
        assign_routes(train, "Ballina", mainline.stops.last[0], mainline.trip_id)

        train
      end

      # Train from Manulla Junction to Ballina (after mainline connection)
      def create_down_train(mainline)
        junction_time = mainline.time_at_junction

        # Depart after mainline arrives plus dwell
        departure = junction_time + crossover.seconds

        train = @builder.from_junction(
          to: "Ballina",
          departure: departure,
          trip_id: mainline.trip_id,
          connects_from: mainline,
          info: "From #{mainline.dir}"
        )

        # Assign to routes connecting mainline origin to Ballina
        assign_routes(train, mainline.stops.first[0], "Ballina", mainline.trip_id)

        train
      end

      def assign_routes(train, from, to, trip_id)
        Domain::Route.connecting(from, to).each do |route|
          train.send("#{route.path_attribute}=", trip_id)
        end
      end

      # Fix trains that overlap (arrival of one too close to departure of next)
      def fix_overlapping_trains(trains)
        sorted = sort_by_terminus_time(trains)

        sorted.each_cons(2) do |current_group, next_group|
          current_arr = terminus_arrival(current_group)
          next_dep = terminus_departure(next_group)

          overlap = current_arr - next_dep
          min_gap = -turnaround.seconds

          next unless overlap > min_gap

          # Need to advance next train group
          adjustment = overlap + turnaround.seconds
          shift_train_group(next_group, adjustment)
        end
      end

      def sort_by_terminus_time(trains)
        # Group by route trip IDs and sort by earliest departure
        nephin_trains = trains.reject { |t| t.nephin_id.nil? }.group_by(&:nephin_id).values
        return_trains = trains.reject { |t| t.nephin_return_id.nil? }.group_by(&:nephin_return_id).values

        (nephin_trains + return_trains).sort_by { |group| group.map(&:dep).min }
      end

      def terminus_arrival(train_group)
        # Latest time at Ballina or Westport
        train_group
          .flat_map(&:stops)
          .select { |s| %w[Ballina Westport].include?(s[0]) }
          .max_by { |s| s[1] }
          &.dig(1)
      end

      def terminus_departure(train_group)
        # Earliest time at Ballina or Westport
        train_group
          .flat_map(&:stops)
          .select { |s| %w[Ballina Westport].include?(s[0]) }
          .min_by { |s| s[1] }
          &.dig(1)
      end

      def shift_train_group(group, seconds)
        group.each do |train|
          train.dep += seconds
          train.arr += seconds
          train.stops.each { |stop| stop[1] += seconds }
          train.info = "advanced by #{(seconds / 60).round} mins to avoid clash"
        end
      end
    end
  end
end
