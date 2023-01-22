require_relative '../models/scenarios/option_3.rb'
require 'test/unit'

class Option3Test < Test::Unit::TestCase

  def setup
    @bw = Option3.new.rows
    @wb = Option3.new("20221222", "Westport", "Ballina").rows
    @bc = Option3.new("20221222", "Ballina", "Castlebar").rows
    @cb = Option3.new("20221222", "Castlebar", "Ballina").rows
    @covey = Option3.new("20221222", "Claremorris", "Westport").rows
    @covey_return = Option3.new("20221222", "Westport", "Claremorris").rows
    @costello = Option3.new("20221222", "Foxford", "Claremorris").rows
    @costello_return = Option3.new("20221222", "Claremorris", "Foxford").rows
    @castlebar_westport =  Option3.new("20221222", "Castlebar", "Westport").rows
  end

  def test_min_dwell_local_trains
    # can't be less than 3 minutes
    rows = (@bw + @wb).sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

    rows = (@covey + @covey_return).select { |t| t.dig(-1) =~ /LC/ }.sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

    # busiest block is Castlebar - Westport
    rows = (Option3.new("20221222", "Westport", "Castlebar").rows + Option3.new("20221222", "Castlebar", "Westport").rows).sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_train_passing
    # TODO
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

  def test_covey
    assert_equal @covey.count, 11
    assert_equal @covey_return.count, 10
    assert_equal @castlebar_westport.count, 19
  end

  def test_costello
    assert_equal @costello.count, 9
    assert_equal @costello_return.count, 10
  end

  def test_analysis
    assert Option3.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
  end
end
