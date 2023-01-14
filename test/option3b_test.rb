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

  def test_min_dwell_local_trains
    # can't be less than 3 minutes
    rows = (@covey + @covey_return).select { |t| t.dig(5) =~ /LC/ }.sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

    # busiest block is Castlebar - Westport
    rows = (Option3b.new("20221222", "Westport", "Castlebar").rows + Option3b.new("20221222", "Castlebar", "Westport").rows).select { |t| t.dig(5) =~ /LC/ }.sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
  end

  def test_train_passing
    # TODO
  end

  def test_covey
    assert_equal @covey.count, 14
    assert_equal @covey_return.count, 13
  end

  def test_costello
    assert_equal @costello.count, 6
    assert_equal @costello_return.count, 6
  end

  def test_analysis
    assert Option3b.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
  end
end
