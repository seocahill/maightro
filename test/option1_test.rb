require_relative '../models/scenarios/option_1a.rb'
require 'test/unit'
require_relative 'test_helpers'

class Option1Test < Test::Unit::TestCase
  include TestHelpers

  def setup
    VCR.use_cassette('option1') do
      @bw = Option1.new.rows
      @wb = Option1.new(last_thursday, "Westport", "Ballina").rows
      @covey = Option1.new(last_thursday, "Claremorris", "Westport").rows
      @costello = Option1.new(last_thursday, "Ballyhaunis", "Foxford").rows
    end
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
    VCR.use_cassette('option1_analysis') do
      assert Option1.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
    end
  end

  # def test_duration
  #   # durations must be realistic based on actual current timings
  #   assert @bw.min { |train| train[4] } > 50, "Duration must be realistic"
  #   assert @wb.min { |train| train[4] } > 50, "Duration must be realistic"
  # end
end
