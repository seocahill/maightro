require 'active_model'

class TrainPath
  include ActiveModel::Model

  def attributes
    [:from, :to, :dep, :arr, :dwell, :info, :group]
  end

  def values
    attributes.map { |attr| self.send(attr) }
  end

  def dep
  end

  def arr
  end

  attr_accessor :from, :to, :dep, :arr, :dwell, :info, :group
end