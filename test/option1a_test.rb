require_relative '../models/scenarios/option_1a.rb'
require 'test/unit'
require_relative 'test_helpers'

class Option1aTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    VCR.use_cassette('option1a') do
      @bw = Option1a.new.rows
      @wb = Option1a.new(last_thursday, "Westport", "Ballina").rows
      @covey = Option1a.new(last_thursday, "Claremorris", "Westport").rows
      @costello = Option1a.new(last_thursday, "Ballyhaunis", "Foxford").rows
    end
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
    VCR.use_cassette('option1a') do
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
  end

  def test_covey
    assert_equal @covey.count, 5
  end

  def test_costello
    assert_equal @costello.count, 5
  end

  def test_analysis
    VCR.use_cassette('option1a_analysis') do
      assert Option1a.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
    end
  end

  def test_bw_duration
    VCR.use_cassette('option1a') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      min_bw_duration = @bw.map { |train| train[5].split.first.to_i }.min
      assert min_bw_duration > 52, "Duration must be realistic; expected greater than 52 but was #{min_bw_duration}"
    end
  end

  def test_wb_duration
    VCR.use_cassette('option1a') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      min_wb_duration = @wb.map { |train| train[5].split.first.to_i }.min
      assert min_wb_duration > 49, "Duration must be realistic; expected greater than 49 but was #{min_wb_duration}"
    end
  end
end
