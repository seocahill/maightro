require "active_support/concern"
require 'time'

module Helper
  extend ActiveSupport::Concern

  def parse_time(time_str="20221222")
    return unless time_str

    Time.parse(time_str[0..3].insert(2, ':'))
  end

  # included do
  #   scope :disabled, -> { where(disabled: true) }
  # end

  # class_methods do
  #   ...
  # end
end
