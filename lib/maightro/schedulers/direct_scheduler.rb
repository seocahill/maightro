# frozen_string_literal: true

require_relative "base_scheduler"

module Maightro
  module Schedulers
    # Direct scheduling algorithm (equivalent to Option2).
    #
    # Strategy: Linear scheduling from 05:00 to 23:59, deciding at each
    # step whether to run a full local trip or create connecting trains.
    #
    # Algorithm:
    # 1. Import mainline Dublin-Westport trains
    # 2. Starting at 05:00 from Ballina, iterate until 23:59
    # 3. At each step, check if a full round trip is possible before next connection
    # 4. If yes: run local train (Ballina <-> Westport)
    # 5. If no: create connecting trains to/from Manulla Junction
    # 6. Apply Castlebar optimization when possible
    #
    class DirectScheduler < BaseScheduler
      def schedule
        import_mainline_trains("Ballyhaunis", "Westport")
        @connecting_trains = trains_at_junction.dup

        @local_trains = []
        @local_index = 0

        schedule_local_trains

        @local_trains + @mainline_trains
      end

      private

      def schedule_local_trains
        dep_time = Time.parse("05:00")
        current_position = "Ballina"

        until dep_time > Time.parse("23:59")
          connecting_train, next_connection = @connecting_trains.min_by(2, &:time_at_junction)

          if full_trip_possible?(connecting_train, current_position, dep_time)
            add_local_train(current_position, dep_time)
          else
            add_connecting_trains(connecting_train, current_position, dep_time, next_connection)
            @connecting_trains.delete(connecting_train)
          end

          last_train = @local_trains.last
          dep_time = last_train.arr + turnaround.seconds
          current_position = last_train.position
          @local_index += 1
        end
      end

      def full_trip_possible?(connecting_train, current_position, dep_time)
        return true unless connecting_train

        trip_duration = duration_of_trip_and_connection(connecting_train, current_position)
        return false unless trip_duration

        dep_time + trip_duration.seconds < connecting_train.time_at_junction
      end

      def duration_of_trip_and_connection(connecting_train, current_position)
        case [connecting_train.to, current_position]
        when ["Westport", "Westport"]
          duration("Westport", "Ballina") + turnaround + duration("Ballina", "Manulla Junction")
        when ["Westport", "Ballina"]
          duration("Ballina", "Westport") + turnaround + duration("Westport", "Manulla Junction")
        when [anything, "Ballina"] # to Dublin
          duration("Ballina", "Westport") + turnaround + duration("Westport", "Ballina") + turnaround + duration("Ballina", "Manulla Junction")
        when [anything, "Westport"]
          duration("Westport", "Ballina") + turnaround + duration("Ballina", "Manulla Junction")
        when [anything, "Castlebar"]
          nil # Can't continue from Castlebar
        else
          nil
        end
      end

      def anything
        # Pattern matching placeholder
        nil
      end

      def add_local_train(current_position, dep_time)
        trip_id = "LDT-#{@local_index}"
        end_station = current_position == "Ballina" ? "Westport" : "Ballina"

        train = @builder.local_train(
          from: current_position,
          to: end_station,
          departure: dep_time,
          trip_id: trip_id,
          info: "local"
        )

        @local_trains << train
      end

      def add_connecting_trains(connecting_train, current_position, dep_time, next_connection)
        up_connection, down_connection = connection_info(connecting_train.dir, current_position)

        # Create up train to junction
        up_train = create_up_train(connecting_train, current_position, up_connection)
        @local_trains << up_train

        # Create down train from junction
        down_train = create_down_train(connecting_train, next_connection, down_connection)
        @local_trains << down_train

        # Apply Castlebar optimization if applicable
        apply_castlebar_optimization(up_train, down_train)

        # Assign route IDs
        assign_local_route_ids(up_train, down_train)
      end

      def create_up_train(connecting_train, current_position, info)
        arrival = connecting_train.time_at_junction - crossover.seconds

        train = @builder.connecting_train(
          from: current_position,
          to: "Manulla Junction",
          arrival: arrival,
          trip_id: connecting_train.trip_id,
          info: info
        )

        # Assign to routes connecting to mainline destination
        unless false_connection?(connecting_train, train)
          assign_routes(train, current_position, connecting_train.stops.last[0], connecting_train.trip_id)
          assign_routes(connecting_train, current_position, connecting_train.stops.last[0], connecting_train.trip_id)
        end

        train
      end

      def create_down_train(connecting_train, next_connection, info)
        departure = connecting_train.time_at_junction + crossover.seconds - crossover.seconds + turnaround.seconds

        # Determine destination based on direction and timing
        end_station = determine_down_destination(connecting_train, next_connection, departure)

        train = @builder.from_junction(
          to: end_station,
          departure: departure,
          trip_id: connecting_train.trip_id,
          info: info
        )

        # Assign routes from mainline origin
        unless false_connection?(connecting_train, train)
          assign_routes(train, connecting_train.stops.first[0], end_station, connecting_train.trip_id)
          assign_routes(connecting_train, connecting_train.stops.first[0], end_station, connecting_train.trip_id)
        end

        train
      end

      def determine_down_destination(connecting_train, next_connection, departure)
        round_trip_time = duration("Westport", "Manulla Junction") + duration("Manulla Junction", "Westport") + turnaround

        if next_connection && (next_connection.time_at_junction - crossover.seconds - connecting_train.time_at_junction < round_trip_time.seconds)
          "Castlebar"
        else
          connecting_train.dir == "Westport" ? "Ballina" : "Westport"
        end
      end

      def apply_castlebar_optimization(up_train, down_train)
        # If going Ballina -> Manulla -> Ballina, try to extend to Castlebar
        return unless up_train.from == "Ballina" && down_train.to == "Ballina"

        prev_train = @local_trains[-3] # Train before up_train
        return unless prev_train

        cbar_offset = duration("Castlebar", "Manulla Junction") + duration("Manulla Junction", "Castlebar") + turnaround

        return unless up_train.dep - cbar_offset.seconds > prev_train.arr + turnaround.seconds

        # Extend to Castlebar
        new_up_dep = up_train.dep - cbar_offset.seconds
        up_train.instance_variable_set(:@to, "Castlebar")
        up_train.instance_variable_set(:@dep, new_up_dep)
        up_train.instance_variable_set(:@stops, @network.stops(up_train.from, "Castlebar", new_up_dep))
        up_train.instance_variable_set(:@arr, up_train.stops.last[1])
        up_train.instance_variable_set(:@trip_id, "LCA-#{@local_index}")
        up_train.nephin_id = up_train.trip_id

        new_down_dep = down_train.dep - duration("Castlebar", "Manulla Junction").seconds - turnaround.seconds
        down_train.instance_variable_set(:@from, "Castlebar")
        down_train.instance_variable_set(:@dep, new_down_dep)
        down_train.instance_variable_set(:@stops, @network.stops("Castlebar", down_train.to, new_down_dep))
        down_train.instance_variable_set(:@trip_id, "LCA-#{@local_index}")
        down_train.nephin_return_id = down_train.trip_id
      end

      def assign_local_route_ids(up_train, down_train)
        trip_id = "LC-#{@local_index}"

        Domain::Route.connecting(up_train.from, down_train.to).each do |route|
          up_train.send("#{route.path_attribute}=", trip_id) if up_train.send(route.path_attribute).nil?
          down_train.send("#{route.path_attribute}=", trip_id) if down_train.send(route.path_attribute).nil?
        end
      end

      def connection_info(dir, pos)
        if dir == "Dublin Heuston" && pos == "Ballina"
          ["To Dublin", "local"]
        else
          ["local", "From Dublin"]
        end
      end

      def false_connection?(connecting_train, local_train)
        connecting_train.dir == "Dublin Heuston" && %w[Westport Castlebar].include?(local_train.to)
      end

      def assign_routes(train, from, to, trip_id)
        Domain::Route.connecting(from, to).each do |route|
          train.send("#{route.path_attribute}=", trip_id)
        end
      end
    end
  end
end
