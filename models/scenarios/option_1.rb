#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo

require 'json'
require 'time'
require 'terminal-table'
require_relative 'base_option'

class Option1 < BaseOption

  attr_reader :results, :train_trips

  def exec_option
    nephin = import_train_data("Ballina", "Westport")
    covey = import_train_data("Westport", "Ballyhaunis")
    costello = import_train_data("Ballyhaunis", "Ballina")
    @train_trips = nephin + covey + costello
  end
end

Option1.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
