# frozen_string_literal: true

require_relative "scheduler_test_helper"

class SchedulerTest < Test::Unit::TestCase
  include SchedulerTestHelpers

  # StatusQuoScheduler (Option1) Tests

  def test_status_quo_trip_counts
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
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      covey = timetable.rows("Claremorris", "Westport")
      assert_equal 5, covey.count, "Covey line should have 5 trains"
    end
  end

  def test_status_quo_costello_line
    VCR.use_cassette("option1") do
      scheduler = Maightro::Schedulers::StatusQuoScheduler.new(date: last_thursday)
      timetable = scheduler.run

      costello = timetable.rows("Ballyhaunis", "Foxford")
      assert_equal 5, costello.count, "Costello line should have 5 trains"
    end
  end

  def test_status_quo_duration_realistic
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

  # OptimizedScheduler (Option1a) Tests

  def test_optimized_trip_counts
    VCR.use_cassette("option1a") do
      scheduler = Maightro::Schedulers::OptimizedScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      assert_equal 5, bw.count, "Ballina-Westport should have 5 trains"
      assert_equal 5, wb.count, "Westport-Ballina should have 5 trains"
    end
  end

  def test_optimized_min_dwell
    VCR.use_cassette("option1a") do
      scheduler = Maightro::Schedulers::OptimizedScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      rows = (bw + wb).sort_by { |r| r[2] }
      min_gap = rows.each_cons(2).map { |s, e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min

      assert_equal 3.0, min_gap, "Minimum dwell must be 3 minutes"
    end
  end

  def test_optimized_trip_duration
    VCR.use_cassette("option1a") do
      scheduler = Maightro::Schedulers::OptimizedScheduler.new(date: last_thursday)
      timetable = scheduler.run

      wb = timetable.rows("Westport", "Ballina")
      bw = timetable.rows("Ballina", "Westport")

      max_wb = wb.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max
      max_bw = bw.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max

      assert max_wb <= 50.0, "WB max duration should be <= 50"
      assert max_bw <= 53.0, "BW max duration should be <= 53"
    end
  end

  # DirectScheduler (Option2) Tests

  def test_direct_trip_counts
    VCR.use_cassette("option2") do
      scheduler = Maightro::Schedulers::DirectScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")
      bc = timetable.rows("Ballina", "Castlebar")
      cb = timetable.rows("Castlebar", "Ballina")

      assert_equal 8, bw.count, "BW should have 8 trains"
      assert_equal 7, wb.count, "WB should have 7 trains"
      assert_equal 11, bc.count, "BC should have 11 trains"
      assert_equal 10, cb.count, "CB should have 10 trains"
    end
  end

  def test_direct_min_dwell
    VCR.use_cassette("option2") do
      scheduler = Maightro::Schedulers::DirectScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      rows = (bw + wb).sort_by { |r| r[2] }
      min_gap = rows.each_cons(2).map { |s, e| (Time.parse(e[2]) - Time.parse(s[3])).fdiv(60) }.min

      assert_equal 3.0, min_gap, "Minimum dwell must be 3 minutes"
    end
  end

  def test_direct_trip_duration
    VCR.use_cassette("option2") do
      scheduler = Maightro::Schedulers::DirectScheduler.new(date: last_thursday)
      timetable = scheduler.run

      wb = timetable.rows("Westport", "Ballina")
      bc = timetable.rows("Ballina", "Castlebar")
      bw = timetable.rows("Ballina", "Westport")
      cb = timetable.rows("Castlebar", "Ballina")

      assert_equal 49.0, wb.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max
      assert_equal 36.0, bc.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max
      assert_equal 53.0, bw.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max
      assert_equal 36.0, cb.map { |r| (Time.parse(r[3]) - Time.parse(r[2])).fdiv(60) }.max
    end
  end

  def test_direct_no_overlaps_ballina_westport
    VCR.use_cassette("option2") do
      scheduler = Maightro::Schedulers::DirectScheduler.new(date: last_thursday)
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")

      all_trains = (bw + wb).sort_by { |train| [train[-1].to_s.split("-").last.to_i, train[2]] }
      all_trains.each_cons(2) do |first_train, second_train|
        next if first_train[1] != second_train[0]

        first_arrival = Time.parse(first_train[3])
        second_departure = Time.parse(second_train[2])

        assert first_arrival <= second_departure, "Overlap detected between #{first_train[7]} and #{second_train[7]}"
      end
    end
  end

  # ExtendedScheduler (Option3) Tests

  def test_extended_trip_counts
    VCR.use_cassette("option3") do
      scheduler = Maightro::Schedulers::ExtendedScheduler.new(date: last_thursday, terminus: "Claremorris")
      timetable = scheduler.run

      bw = timetable.rows("Ballina", "Westport")
      wb = timetable.rows("Westport", "Ballina")
      bc = timetable.rows("Ballina", "Castlebar")
      cb = timetable.rows("Castlebar", "Ballina")

      assert_equal 8, bw.count, "BW should have 8 trains"
      assert_equal 7, wb.count, "WB should have 7 trains"
      assert_equal 11, bc.count, "BC should have 11 trains"
      assert_equal 10, cb.count, "CB should have 10 trains"
    end
  end

  def test_extended_covey_line
    VCR.use_cassette("option3") do
      scheduler = Maightro::Schedulers::ExtendedScheduler.new(date: last_thursday, terminus: "Claremorris")
      timetable = scheduler.run

      covey = timetable.rows("Claremorris", "Westport")
      covey_return = timetable.rows("Westport", "Claremorris")
      castlebar_westport = timetable.rows("Castlebar", "Westport")

      assert_equal 11, covey.count, "Covey should have 11 trains"
      assert_equal 10, covey_return.count, "Covey return should have 10 trains"
      assert_equal 19, castlebar_westport.count, "Castlebar-Westport should have 19 trains"
    end
  end

  # Factory Tests

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

  # Analysis Tests

  def test_analysis_produces_valid_results
    VCR.use_cassette("option1") do
      result = Maightro::Schedulers.for_option("Option1", date: last_thursday)
      analysis = result.run_analysis

      assert analysis.all? { |r| r[2..5].min.positive? }, "Analysis should have positive stats"
    end
  end
end
