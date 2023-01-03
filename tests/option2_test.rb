require_relative '../models/scenarios/option_2.rb'
require 'test/unit'
require 'pry'

class Option2Test < Test::Unit::TestCase

  def setup
    @rows = Option2.new.rows
  end

  def test_results_length
    assert_equal @rows.length, 21
  end

  def test_min_dwell
    # can't be less than 3 minutes
    assert_equal @rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_trip_counts
    counts = @rows.map { |r| r[0..1].join('-') }.tally
    assert_equal counts["Ballina-Westport"], 8
    assert_equal counts["Westport-Ballina"], 7
    assert_equal counts["Ballina-Castlebar"], 3
    assert_equal counts["Castlebar-Ballina"], 3
  end

  def test_trip_duration
    @rows.select { |r| r[0..1].sort == %w[Ballina Westport]}.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max == 49.0
    @rows.select { |r| r[0..1].sort == %w[Ballina Castlebar]}.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max == 36.0
  end
end
