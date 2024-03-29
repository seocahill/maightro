# frozen_string_literal: true

require 'active_model'
require_relative 'helper'

class TrainPath
  include ActiveModel::Model
  include Helper

  def attributes
    %i[from to dep arr dwell info trip_id dir position stops connection nephin_id covey_id costello_id nephin_return_id covey_return_id costello_return_id]
  end

  def self.create(train, trip, stations)
    new(
      from: find_station(train['dep'], stations),
      to: find_station(train['arr'], stations),
      arr: parse_time(train['arr']['aTimeS']),
      dep: parse_time(train['dep']['dTimeS']),
      info: "to #{train['jny']['dirTxt']}",
      dir: train['jny']['dirTxt'],
      trip_id: trip['cid'],
      stops: populate_stop_information(train, stations)
    ).tap do |train_path|
      train_path.find_route(train_path.stops.first[0], train_path.stops.last[0]).dig(0).each do |route|
        train_path.send("#{route}_id=", train_path.trip_id)
      end
    end
  end

  def time_at_junction
    stops.detect { |s| s[0] == 'Manulla Junction' }&.dig(1)
  end

  def values
    attributes.map { |attr| send(attr) }
  end

  def manulla_time
    if from == 'Manulla Junction'
      dep
    else
      arr # from Westport, arriving in Manulla
    end
  end

  def arr_time
    arr.strftime('%H:%M')
  end

  def dep_time
    dep.strftime('%H:%M')
  end

  attr_accessor :from, :to, :dep, :arr, :dwell, :info, :trip_id, :dir,
                :position, :stops, :connection, :nephin_id, :covey_id,
                :costello_id, :nephin_return_id, :covey_return_id,
                :costello_return_id
end
