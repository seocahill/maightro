require_relative '../models/scenarios/option_3b.rb'
require 'test/unit'
require 'pry'

class Option3bTest < Test::Unit::TestCase

  def setup
    @covey = Option3b.new("20221222", "Ballyhaunis", "Westport").rows
    @covey_return = Option3b.new("20221222", "Westport", "Ballyhaunis").rows
    @costello = Option3b.new("20221222", "Foxford", "Ballyhaunis").rows
    @costello_return = Option3b.new("20221222", "Ballyhaunis", "Foxford").rows
  end

  def test_min_dwell
    # can't be less than 3 minutes
    rows = (@covey + @covey_return).sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_covey
    assert_equal @covey.count, 11
    assert_equal @covey_return.count, 10
  end

  def test_costello
    assert_equal @costello.count, 9
    assert_equal @costello_return.count, 10
  end
end
