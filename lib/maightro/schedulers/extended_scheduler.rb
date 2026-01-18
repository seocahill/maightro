# frozen_string_literal: true

require_relative "base_scheduler"
require_relative "direct_scheduler"

module Maightro
  module Schedulers
    # Extended scheduling algorithm (equivalent to Option3/3b).
    #
    # Strategy: Build on DirectScheduler's Ballina service and add
    # a second railcar running Claremorris/Ballyhaunis <-> Westport.
    #
    # Algorithm:
    # 1. Run DirectScheduler to get Ballina trains
    # 2. Extract Ballina-Westport connecting trains
    # 3. Schedule second railcar to meet those connections
    # 4. Fill gaps with local Westport <-> terminus trains
    #
    # @param terminus [String] "Claremorris" (Option3) or "Ballyhaunis" (Option3b)
    #
    class ExtendedScheduler < BaseScheduler
      attr_reader :terminus

      def initialize(date: nil, network: nil, constraints: nil, terminus: "Claremorris")
        super(date: date, network: network, constraints: constraints)
        @terminus = terminus
      end

      def schedule
        # Get base trains from DirectScheduler
        direct_scheduler = DirectScheduler.new(date: @date, network: @network, constraints: @constraints)
        @base_trains = direct_scheduler.schedule

        # Extract Ballina-Westport trains to connect with
        @connecting_trains = @base_trains.select do |t|
          [t.from, t.to].sort == %w[Ballina Westport]
        end

        @covey_trains = []
        @trip_index = 0

        schedule_covey_trains

        (@covey_trains + @base_trains).sort_by(&:dep)
      end

      private

      def schedule_covey_trains
        dep_time = Time.parse("05:00")
        current_position = @terminus

        until dep_time > Time.parse("23:59")
          connecting_train = @connecting_trains.first

          train = if train_in_wrong_position?(connecting_train, current_position)
                    create_repositioning_train(current_position, dep_time)
                  elsif can_connect?(connecting_train, current_position, dep_time)
                    create_connection_train(connecting_train, current_position).tap do
                      @connecting_trains.delete(connecting_train)
                    end
                  else
                    create_local_train(current_position, dep_time).tap do
                      @connecting_trains.delete(connecting_train)
                    end
                  end

          @covey_trains << train
          dep_time = train.arr + turnaround.seconds
          current_position = train.to
          @trip_index += 1
        end
      end

      def train_in_wrong_position?(connecting_train, current_position)
        return false unless connecting_train

        if connecting_train.from == "Ballina" && current_position == "Westport"
          false
        elsif connecting_train.from == "Westport" && current_position == @terminus
          false
        elsif connecting_train.from == "Castlebar" && current_position == @terminus
          false
        else
          true
        end
      end

      def can_connect?(connecting_train, current_position, dep_time)
        return false unless connecting_train

        required_dep = if current_position == @terminus
                         connecting_train.time_at_junction - duration(@terminus, "Manulla Junction").seconds
                       else
                         connecting_train.time_at_junction - duration("Westport", "Manulla Junction").seconds
                       end

        dep_time <= required_dep
      end

      def create_repositioning_train(current_position, dep_time)
        trip_id = "LCTR-#{@trip_index}"

        if current_position == @terminus
          to = "Westport"
          route_attr = :covey_return_id
        else
          to = @terminus
          route_attr = :covey_id
        end

        train = @builder.local_train(
          from: current_position,
          to: to,
          departure: dep_time,
          trip_id: trip_id,
          info: "local"
        )

        train.send("#{route_attr}=", trip_id)
        train
      end

      def create_connection_train(connecting_train, current_position)
        trip_id = "LCX-#{@trip_index}"

        if current_position == @terminus
          dep = connecting_train.time_at_junction - duration(@terminus, "Manulla Junction").seconds
          arr = connecting_train.time_at_junction + duration("Manulla Junction", "Westport").seconds
          to = "Westport"
          route_attr = :covey_return_id
        else
          dep = connecting_train.time_at_junction - duration("Westport", "Manulla Junction").seconds
          arr = connecting_train.time_at_junction + duration("Manulla Junction", @terminus).seconds
          to = @terminus
          route_attr = :covey_id
        end

        stops = @network.stops(current_position, to, dep)

        train = build_simple_path(
          from: current_position,
          to: to,
          dep: dep,
          arr: arr,
          stops: stops,
          trip_id: connecting_train.trip_id
        )

        train.send("#{route_attr}=", trip_id)

        # Assign routes for connection
        assign_connection_routes(train, connecting_train, trip_id)

        train
      end

      def create_local_train(current_position, dep_time)
        trip_id = "LCL-#{@trip_index}"

        if current_position == @terminus
          to = "Westport"
          route_attr = :covey_return_id
        else
          to = @terminus
          route_attr = :covey_id
        end

        train = @builder.local_train(
          from: current_position,
          to: to,
          departure: dep_time,
          trip_id: trip_id,
          info: "local"
        )

        train.send("#{route_attr}=", trip_id)
        train
      end

      def assign_connection_routes(train, connecting_train, trip_id)
        # From train origin to connecting train destination
        Domain::Route.connecting(train.from, connecting_train.stops.last[0]).each do |route|
          train.send("#{route.path_attribute}=", trip_id)
          connecting_train.send("#{route.path_attribute}=", trip_id)
        end

        # From connecting train origin to train destination
        Domain::Route.connecting(connecting_train.stops.first[0], train.to).each do |route|
          train.send("#{route.path_attribute}=", trip_id)
          connecting_train.send("#{route.path_attribute}=", trip_id)
        end
      end

      def build_simple_path(from:, to:, dep:, arr:, stops:, trip_id:)
        Maightro::Services::TrainPathBuilder::SimplePath.new(
          from: from,
          to: to,
          dep: dep,
          arr: arr,
          stops: stops,
          trip_id: trip_id,
          dir: "local",
          info: "local",
          position: to
        )
      end
    end
  end
end
