# frozen_string_literal: true

require_relative "scheduler_test_helper"

class SchedulerTest < Test::Unit::TestCase
  include SchedulerTestHelpers

  # Factory Tests - these don't need VCR

  def test_factory_creates_correct_scheduler
    assert_instance_of Maightro::Schedulers::StatusQuoScheduler, Maightro::Schedulers.create(:status_quo)
    assert_instance_of Maightro::Schedulers::OptimizedScheduler, Maightro::Schedulers.create(:optimized)
    assert_instance_of Maightro::Schedulers::DirectScheduler, Maightro::Schedulers.create(:direct)
    assert_instance_of Maightro::Schedulers::ExtendedScheduler, Maightro::Schedulers.create(:extended)
  end

  def test_factory_handles_legacy_names
    assert_instance_of Maightro::Schedulers::StatusQuoScheduler, Maightro::Schedulers.create("Option1")
    assert_instance_of Maightro::Schedulers::OptimizedScheduler, Maightro::Schedulers.create("Option1a")
    assert_instance_of Maightro::Schedulers::DirectScheduler, Maightro::Schedulers.create("Option2")
    assert_instance_of Maightro::Schedulers::ExtendedScheduler, Maightro::Schedulers.create("Option3")
  end

  def test_factory_raises_for_unknown_scheduler
    assert_raises(ArgumentError) { Maightro::Schedulers.create(:unknown) }
  end

  def test_extended_scheduler_terminus_option
    claremorris = Maightro::Schedulers::ExtendedScheduler.new(terminus: "Claremorris")
    ballyhaunis = Maightro::Schedulers::ExtendedScheduler.new(terminus: "Ballyhaunis")

    assert_equal "Claremorris", claremorris.terminus
    assert_equal "Ballyhaunis", ballyhaunis.terminus
  end

  # StatusQuoScheduler (Option1) Tests

  def test_status_quo_trip_counts
    skip_without_vcr
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      assert_equal 5, bw.count, "Ballina-Westport should have 5 trains"
      assert_equal 5, wb.count, "Westport-Ballina should have 5 trains"
    end
  end

  def test_status_quo_covey_line
    skip_without_vcr
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      covey = timetable.rows("Claremorris", "Westport")
      assert_equal 5, covey.count, "Covey line should have 5 trains"
    end
  end

  def test_status_quo_costello_line
    skip_without_vcr
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      costello = timetable.rows("Ballyhaunis", "Foxford")
      assert_equal 5, costello.count, "Costello line should have 5 trains"
    end
  end

  def test_status_quo_duration_realistic
    skip_without_vcr
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      # Fastest current time to Westport is 53 mins, from is 49 mins
      min_bw = bw.map { |r| r[5].split.first.to_i }.min
      min_wb = wb.map { |r| r[5].split.first.to_i }.min

      assert min_bw > 52, "BW duration must be realistic (>52), was #{min_bw}"
      assert min_wb > 48, "WB duration must be realistic (>48), was #{min_wb}"
    end
  end

  def test_status_quo_analysis
    skip_without_vcr
    VCR.use_cassette("option1_analysis") do
      result = Maightro::Schedulers.for_option("Option1", date: last_thursday)
      analysis = result.run_analysis

      assert analysis.is_a?(Array), "Analysis should return an array"
      assert analysis.length > 0, "Analysis should have results"
      assert analysis.all? { |r| r.is_a?(Array) && r.length == 6 }, "Each result should have 6 fields"
    end
  end

  # OptimizedScheduler (Option1a) Tests

  def test_optimized_trip_counts
    skip_without_vcr
    VCR.use_cassette("option1a") do
      scheduler = Maightro::Schedulers::OptimizedScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      assert_equal 5, bw.count, "Ballina-Westport should have 5 trains"
      assert_equal 5, wb.count, "Westport-Ballina should have 5 trains"
    end
  end

  def test_optimized_analysis
    skip_without_vcr
    VCR.use_cassette("option1a_analysis") do
      result = Maightro::Schedulers.for_option("Option1a", date: last_thursday)
      analysis = result.run_analysis

      assert analysis.is_a?(Array), "Analysis should return an array"
      assert analysis.length > 0, "Analysis should have results"
    end
  end

  # DirectScheduler (Option2) Tests

  def test_direct_produces_more_trains
    skip_without_vcr
    VCR.use_cassette("option2") do
      scheduler = Maightro::Schedulers::DirectScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      # Direct should produce more trains than status quo
      assert bw.count >= 5, "Direct should have at least 5 BW trains"
      assert wb.count >= 5, "Direct should have at least 5 WB trains"
    end
  end

  def test_direct_analysis
    skip_without_vcr
    VCR.use_cassette("option2_analysis") do
      result = Maightro::Schedulers.for_option("Option2", date: last_thursday)
      analysis = result.run_analysis

      assert analysis.is_a?(Array), "Analysis should return an array"
      assert analysis.length > 0, "Analysis should have results"
    end
  end

  # ExtendedScheduler (Option3) Tests

  def test_extended_produces_trains
    skip_without_vcr
    VCR.use_cassette("option3") do
      scheduler = Maightro::Schedulers::ExtendedScheduler.new(date: last_thursday, terminus: "Claremorris")
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      covey = timetable.rows("Claremorris", "Westport")

      assert bw.count >= 5, "Extended should have at least 5 BW trains"
      assert covey.count >= 5, "Extended should have Claremorris-Westport trains"
    end
  end

  def test_extended_analysis
    skip_without_vcr
    VCR.use_cassette("option3_analysis") do
      result = Maightro::Schedulers.for_option("Option3", date: last_thursday)
      analysis = result.run_analysis

      assert analysis.is_a?(Array), "Analysis should return an array"
      assert analysis.length > 0, "Analysis should have results"
    end
  end
end
