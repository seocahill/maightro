#! /usr/bin/ruby
# frozen_string_literal: true

# Add Ballyhaunis block (15 mins)

require_relative 'option_3'

class Option3b < Option3
  def exec_option
    @claremorris_trains = []
    @covey_terminus = "Ballyhaunis"
    @trip_id_idx = 0
    schedule_trains
  end


  def attempt_to_cross_trains
    @haunis_trains.sort_by(&:dep).each_cons(2) do |cur, nxt|
      next if cur.nil?

      overlap = (nxt.dep - cur.arr).fdiv(60).round
      next unless overlap <= -(@turnaround)

      # check if they can cross anywhere else
      next if cur.stops.any? do |name, time|
        match = nxt.detect { |s| s[0] == name }
        (match.dig(1) - time).abs <= 3
      end

      puts ["removing clash", cur.arr, nxt.dep].join(' ')
      @haunis_trains.delete cur
    end
  end
end

Option3b.new(*ARGV).as_ascii if __FILE__ == $PROGRAM_NAME
