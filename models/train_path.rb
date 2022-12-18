# frozen_string_literal: true

require 'active_model'
require_relative 'helper'

class TrainPath
  include ActiveModel::Model
  include Helper

  def attributes
    %i[from to dep arr dwell info trip_id dir position]
  end

  def self.create(train, trip, stations)
    new(
      from: find_station(train['dep'], stations),
      to: find_station(train['arr'], stations),
      arr: parse_time(train['arr']['aTimeS']),
      dep: parse_time(train['dep']['dTimeS']),
      info: "to #{train['jny']['dirTxt']}",
      dir: train['dir'],
      trip_id: trip['cid']
    )
  end

  def values
    attributes.map { |attr| send(attr) }
  end

  def time
    dep || arr
  end

  attr_accessor :from, :to, :dep, :arr, :dwell, :info, :trip_id, :dir, :position
end
