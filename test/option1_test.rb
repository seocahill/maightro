# frozen_string_literal: true

require_relative '../models/scenarios/option_1a'
require 'test/unit'

class Option1Test < Test::Unit::TestCase
  def setup
    @bw = Option1.new.rows
    @wb = Option1.new('20221222', 'Westport', 'Ballina').rows
    @covey = Option1.new('20221222', 'Claremorris', 'Westport').rows
    @costello = Option1.new('20221222', 'Ballyhaunis', 'Foxford').rows
  end

  def test_trip_counts
    assert_equal @bw.count, 5
    assert_equal @wb.count, 5
  end

  def test_covey
    assert_equal @covey.count, 5
  end

  def test_costello
    assert_equal @costello.count, 5
  end

  def test_analysis
    assert Option1.new.run_analysis.all? { |r| r[3..5].min.positive? }, 'Sanity: no negative stats'
  end
end
