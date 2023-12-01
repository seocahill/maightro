require_relative '../models/scenarios/option_2.rb'
require 'test/unit'
require_relative 'test_helpers'


class Option2Test < Test::Unit::TestCase
  include TestHelpers

  def setup
    VCR.use_cassette('option2') do
      @bw = Option2.new.rows
      @wb = Option2.new(last_thursday, "Westport", "Ballina").rows
      @bc = Option2.new(last_thursday, "Ballina", "Castlebar").rows
      @cb = Option2.new(last_thursday, "Castlebar", "Ballina").rows
      @covey = Option2.new(last_thursday, "Claremorris", "Westport").rows
      @costello = Option2.new(last_thursday, "Ballyhaunis", "Foxford").rows
    end
  end

  def test_min_dwell
    # can't be less than 3 minutes
    rows = (@bw + @wb).sort_by { |r| r[2] }
    assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
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
    VCR.use_cassette('option2') do
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

  def test_covey
    assert_equal @covey.count, 5
  end

  def test_costello
    assert_equal @costello.count, 5
  end

  def test_analysis
    VCR.use_cassette('option2_analysis') do
      assert Option2.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
    end
  end

  def test_bw_duration
    VCR.use_cassette('option2') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      min_bw_duration = @bw.select { |train| train.last.start_with?("LC-") }.map { |train| train[5].split.first.to_i }.min
      assert min_bw_duration > 52, "Duration must be realistic; expected greater than 52 but was #{min_bw_duration}"
    end
  end

  def test_wb_duration
    VCR.use_cassette('option2') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      # manulla dwell is 3 minutes for changes
      min_wb_duration = @wb.select { |train| train.last.start_with?("LC-") }.map { |train| train[5].split.first.to_i }.min
      assert min_wb_duration > 48, "Duration must be realistic; expected greater than 49 but was #{min_wb_duration}"
    end
  end
end
