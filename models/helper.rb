# frozen_string_literal: true

require 'active_support/concern'
require 'time'

module Helper
  extend ActiveSupport::Concern

  def parse_time(time_str = '20221222')
    return unless time_str

    Time.parse(time_str[0..3].insert(2, ':'))
  end

  def find_station(current, stations)
    index = current['locX']
    stations.dig(index, 'name')
  end

  # included do
  #   scope :disabled, -> { where(disabled: true) }
  # end

  def find_route(from, to)
    nephin = ["Ballina", "Foxford", "Manulla Junction", "Castlebar", "Westport"]
    covey = ["Westport", "Castlebar", "Manulla Junction", "Claremorris", "Ballyhaunis"]
    costello = ["Ballyhaunis", "Claremorris", "Manulla Junction", "Foxford", "Ballina"]

    [nephin, covey, costello, nephin.reverse, covey.reverse, costello.reverse].each do |r|
      next unless sdx = r.index(from)
      next unless edx = r[sdx..].index(to)
      return r[sdx..edx]
    end
  end

  def stops(from, to, dep)
    results = [[from, dep]]
    current = dep
    find_route(from, to).each_cons(2) do |f,t|
      next unless f && t

      current += (@stop_info[f][t] + @dwell)
      results << [t, current]
    end
    results
  end

  # def stops(row)
  #   bw = [
  #       ["Foxford", (Time.parse(row[2]) + (16*60)).strftime("%H:%M")],
  #       ["Manulla", (Time.parse(row[2]) + (27*60)).strftime("%H:%M")],
  #       ["Castlebar", (Time.parse(row[2]) + (36*60)).strftime("%H:%M")],
  #     ]
  #   wb = [
  #     ["Castlebar", (Time.parse(row[2]) + (14*60)).strftime("%H:%M")],
  #     ["Manulla", (Time.parse(row[2]) + (20*60)).strftime("%H:%M")],
  #     ["Foxford", (Time.parse(row[2]) + (31*60)).strftime("%H:%M")],
  #     ]
  #   if row[0] == "Ballina" && row[1] == "Westport"
  #     bw
  #   elsif row[1] == "Ballina" && row[0] == "Westport"
  #     wb
  #   elsif row[0] == "Ballina" && row[1] == "Castlebar"
  #     bw[0..1]
  #   elsif row[1] == "Ballina" && row[0] == "Castlebar"
  #     wb[1..2]
  #   end
  # end



  class_methods do
    def parse_time(time_str = '20221222')
      return unless time_str

      Time.parse(time_str[0..3].insert(2, ':'))
    end

    def find_station(current, stations)
      index = current['locX']
      stations.dig(index, 'name').split.first
    end
  end
end
