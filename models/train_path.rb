require 'active_model'

class TrainPath
  include ActiveModel::Model

  def attributes
    [:from, :dir, :dep, :arr, :station]
  end

  def values
    attributes.map { |attr| self.send(attr) }
  end

  def dep
  end

  def arr
  end

  attr_accessor :from, :dir, :dep, :arr, :station
end