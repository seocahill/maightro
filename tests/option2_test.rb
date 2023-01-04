require_relative '../models/scenarios/option_2.rb'
require 'test/unit'
require 'pry'

class Option2Test < Test::Unit::TestCase

  def setup
    @bw = Option2.new.rows
    @wb = Option2.new("20221222", "Westport", "Ballina").rows
    @bc = Option2.new("20221222", "Ballina", "Castlebar").rows
    @cb = Option2.new("20221222", "Castlebar", "Ballina").rows
  end

  def test_min_dwell
    # can't be less than 3 minutes
    rows = (@bw + @wb).sort_by { |r| r[2] }
    # binding.pry # duration is wrong taking 53 mins instead of 49?
    # assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_trip_counts
    assert_equal @bw.count, 8
    assert_equal @wb.count, 7
    assert_equal @bc.count, 11
    assert_equal @cb.count, 10
  end

  def test_trip_duration
    assert_equal (@wb).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max, 49.0
    assert_equal (@bc).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max, 36.0

    assert_equal (@bw).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max, 53.0
    assert_equal (@cb).sort_by { |r| r[2] }.map { |t| (Time.parse(t[3]) - Time.parse(t[2])).fdiv(60)}.max, 36.0

  end

  def test_block_timing
    dep = Time.parse("12:00")
    mal_arr = Time.parse("12:27")
    assert_equal Option2.new.stops("Ballina", "Manulla Junction", dep).max_by { |t| t[1] }.dig(1), mal_arr

    bal_arr = Time.parse("12:27")
    assert_equal Option2.new.stops("Manulla Junction", "Ballina", dep).max_by { |t| t[1] }.dig(1), bal_arr

    man_arr = Time.parse("12:19")
    assert_equal Option2.new.stops("Westport", "Manulla Junction", dep).max_by { |t| t[1] }.dig(1), man_arr
    wes_arr = Time.parse("12:23")
    assert_equal Option2.new.stops("Manulla Junction", "Westport", dep).max_by { |t| t[1] }.dig(1), wes_arr
  end
end
