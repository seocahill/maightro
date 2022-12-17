require 'active_model'

class TrainPath
  include ActiveModel::Model

  def attributes
    [:from, :to, :dep, :arr, :dwell, :info, :trip_id]
  end

  def self.create(train, trip, stations)
    new(
      from: find_station(train['dep'], stations),
      to: find_station(train['arr'], stations),
      arr: parse_time(train['arr']['aTimeS']),
      dep: parse_time(train['dep']['dTimeS']),
      info:  "to " + train['jny']['dirTxt'],
      trip_id: trip['cid']
    )
  end

  def values
    attributes.map { |attr| self.send(attr) }
  end

  def dep
  end

  def arr
  end

  attr_accessor :from, :to, :dep, :arr, :dwell, :info, :trip_id
end