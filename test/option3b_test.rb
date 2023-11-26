require_relative '../models/scenarios/option_3b.rb'
require 'test/unit'
require_relative 'test_helpers'


class Option3bTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    VCR.use_cassette('option3b') do
      @covey = Option3b.new(last_thursday, "Ballyhaunis", "Westport").rows
      @covey_return = Option3b.new(last_thursday, "Westport", "Ballyhaunis").rows
      @costello = Option3b.new(last_thursday, "Foxford", "Ballyhaunis").rows
      @costello_return = Option3b.new(last_thursday, "Ballyhaunis", "Foxford").rows
    end
  end

  def test_min_dwell_local_trains
    VCR.use_cassette('option3b') do
      # can't be less than 3 minutes
      rows = (@covey + @covey_return).select { |t| t.dig(-1) =~ /LC/ }.sort_by { |r| r[2] }
      assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

      # busiest block is Castlebar - Westport
      rows = (Option3b.new(last_thursday, "Westport", "Castlebar").rows + Option3b.new(last_thursday, "Castlebar", "Westport").rows).select { |t| t.dig(-1) =~ /LC/ }.sort_by { |r| r[2] }
      assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
    end
  end

  def test_train_passing
    # TODO
  end

  def test_covey
    assert_equal @covey.count, 10
    assert_equal @covey_return.count, 10
  end

  def test_costello
    assert_equal @costello.count, 9
    assert_equal @costello_return.count, 8
  end

  def test_analysis
    VCR.use_cassette('option3b') do
      assert Option3b.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
    end
  end
end
