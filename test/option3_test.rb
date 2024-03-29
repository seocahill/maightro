require_relative '../models/scenarios/option_3.rb'
require 'test/unit'
require_relative 'test_helpers'


class Option3Test < Test::Unit::TestCase
  include TestHelpers

  def setup
    VCR.use_cassette('option3') do
      @bw = Option3.new.rows
      @wb = Option3.new(last_thursday, "Westport", "Ballina").rows
      @bc = Option3.new(last_thursday, "Ballina", "Castlebar").rows
      @cb = Option3.new(last_thursday, "Castlebar", "Ballina").rows
      @covey = Option3.new(last_thursday, "Claremorris", "Westport").rows
      @covey_return = Option3.new(last_thursday, "Westport", "Claremorris").rows
      @covey_sunday = Option3.new(last_sunday, "Claremorris", "Westport").rows
      @covey_return_sunday = Option3.new(last_sunday, "Westport", "Claremorris").rows
      @costello = Option3.new(last_thursday, "Foxford", "Claremorris").rows
      @costello_return = Option3.new(last_thursday, "Claremorris", "Foxford").rows
      @costello_sunday = Option3.new(last_sunday, "Foxford", "Claremorris").rows
      @costello_return_sunday = Option3.new(last_sunday, "Claremorris", "Foxford").rows
      @castlebar_westport =  Option3.new(last_thursday, "Castlebar", "Westport").rows
    end
  end

  def test_min_dwell_local_trains
    VCR.use_cassette('option3') do
      # can't be less than 3 minutes
      rows = (@bw + @wb).sort_by { |r| r[2] }
      assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

      rows = (@covey + @covey_return).select { |t| t.dig(-1) =~ /LC/ }.sort_by { |r| r[2] }
      assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0

      # busiest block is Castlebar - Westport
      rows = (Option3.new(last_thursday, "Westport", "Castlebar").rows + Option3.new(last_thursday, "Castlebar", "Westport").rows).sort_by { |r| r[2] }
      assert_equal rows.each_cons(2).map {|s,e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min, 3.0
    end
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

  def test_covey_sunday
    assert_equal @covey_sunday.count, 12
    assert_equal @covey_return_sunday.count, 11
  end

  def test_costello
    assert_equal @costello.count, 9
    assert_equal @costello_return.count, 10
  end

  def test_costello_sunday
    assert_equal @costello_sunday.count, 8
    assert_equal @costello_return_sunday.count, 9
  end

  def test_analysis
    VCR.use_cassette('option3_analysis') do
      assert Option3.new.run_analysis.all? { |r| r[3..5].min.positive? }, "Sanity: no negative stats"
    end
  end

  def test_bw_duration
    VCR.use_cassette('option3') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      min_bw_duration = @bw.select { |train| train.last.start_with?("LC-") }.map { |train| train[5].split.first.to_i }.min
      assert min_bw_duration > 52, "Duration must be realistic; expected greater than 52 but was #{min_bw_duration}"
    end
  end

  def test_wb_duration
    VCR.use_cassette('option3') do
      # durations must be realistic based on actual current timings
      # fastest current time to westport is 53 mins, from is 49 mins.
      # manulla dwell is 3 minutes for changes
      min_wb_duration = @wb.select { |train| train.last.start_with?("LC-") }.map { |train| train[5].split.first.to_i }.min
      assert min_wb_duration > 48, "Duration must be realistic; expected greater than 49 but was #{min_wb_duration}"
    end
  end
end
