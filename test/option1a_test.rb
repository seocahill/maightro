require_relative '../models/scenarios/option_1a.rb'
require 'test/unit'
require 'pry'

class Option1aTest < Test::Unit::TestCase

  def setup
    @bw = Option1a.new.rows
    @wb = Option1a.new("20221222", "Westport", "Ballina").rows
    @covey = Option1a.new("20221222", "Claremorris", "Westport").rows
    @costello = Option1a.new("20221222", "Ballyhaunis", "Foxford").rows
  end

  def test_min_dwell
    # can't be less than 3 minutes
    rows = (@bw + @wb).sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_trip_counts
    assert_equal @bw.count, 5
    assert_equal @wb.count, 5
  end

  def test_trip_duration
    assert (@wb).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max <= 49.0
    assert (@bw).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max <= 53.0
  end

  def test_train_passing
    # TODO
  end

  def test_block_timing
    dep = Time.parse("12:00")
    mal_arr = Time.parse("12:27")
    assert_equal Option1a.new.stops("Ballina", "Manulla Junction", dep).max_by { |t| t[1] }.dig(1), mal_arr

    bal_arr = Time.parse("12:27")
    assert_equal Option1a.new.stops("Manulla Junction", "Ballina", dep).max_by { |t| t[1] }.dig(1), bal_arr

    man_arr = Time.parse("12:19")
    assert_equal Option1a.new.stops("Westport", "Manulla Junction", dep).max_by { |t| t[1] }.dig(1), man_arr
    wes_arr = Time.parse("12:23")
    assert_equal Option1a.new.stops("Manulla Junction", "Westport", dep).max_by { |t| t[1] }.dig(1), wes_arr
  end

  def test_covey
    assert_equal @covey.count, 5
  end

  def test_costello
    assert_equal @costello.count, 5
  end
end
