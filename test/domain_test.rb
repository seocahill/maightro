# frozen_string_literal: true

require "test/unit"
require_relative "../lib/maightro"

class DomainTest < Test::Unit::TestCase
  # Station tests
  def test_station_equality
    ballina1 = Maightro::Domain::Station.new("Ballina")
    ballina2 = Maightro::Domain::Station[:ballina]

    assert_equal ballina1, ballina2
  end

  def test_station_factory
    station = Maightro::Domain::Station[:westport]

    assert_equal "Westport", station.name
    assert_equal :westport, station.to_sym
  end

  def test_station_junction
    manulla = Maightro::Domain::Station[:manulla]
    ballina = Maightro::Domain::Station[:ballina]

    assert manulla.junction?
    refute ballina.junction?
  end

  def test_passenger_stations
    passengers = Maightro::Domain::Station.passenger_stations

    assert_equal 6, passengers.size
    refute passengers.any?(&:junction?)
  end

  # Duration tests
  def test_duration_arithmetic
    three_mins = Maightro::Domain::Duration.minutes(3)
    six_mins = Maightro::Domain::Duration.minutes(6)

    assert_equal 9, (three_mins + six_mins).to_minutes
    assert_equal 3, (six_mins - three_mins).to_minutes
    assert_equal 12, (three_mins * 4).to_minutes
  end

  def test_duration_comparison
    short = Maightro::Domain::Duration.minutes(3)
    long = Maightro::Domain::Duration.minutes(10)

    assert short < long
    assert long > short
  end

  def test_duration_to_s
    d = Maightro::Domain::Duration.minutes(90)

    assert_equal "1h 30m", d.to_s
  end

  # Route tests
  def test_route_factory
    nephin = Maightro::Domain::Route[:nephin]

    assert_equal "Ballina", nephin.origin
    assert_equal "Westport", nephin.terminus
  end

  def test_route_return
    nephin = Maightro::Domain::Route[:nephin]
    nephin_return = nephin.return

    assert_equal "Westport", nephin_return.origin
    assert_equal "Ballina", nephin_return.terminus
    assert nephin_return.return_route?
  end

  def test_route_connects
    nephin = Maightro::Domain::Route[:nephin]

    assert nephin.connects?("Ballina", "Westport")
    assert nephin.connects?("Foxford", "Castlebar")
    refute nephin.connects?("Westport", "Ballina") # wrong direction
  end

  def test_route_connecting
    routes = Maightro::Domain::Route.connecting("Foxford", "Castlebar")

    assert routes.any? { |r| r.name == :nephin }
  end

  def test_route_stops_between
    nephin = Maightro::Domain::Route[:nephin]
    stops = nephin.stops_between("Foxford", "Castlebar")

    assert_equal %w[Foxford Manulla\ Junction Castlebar], stops
  end

  # Constraints tests
  def test_default_constraints
    c = Maightro::Domain::Constraints.default

    assert_equal 3, c.dwell.to_minutes
    assert_equal 9, c.turnaround.to_minutes
    assert_equal 9, c.crossover.to_minutes
  end

  def test_can_turn
    c = Maightro::Domain::Constraints.default
    arrival = Time.parse("10:00")

    assert c.can_turn?(arrival, Time.parse("10:10"))
    refute c.can_turn?(arrival, Time.parse("10:05"))
  end

  # Network tests
  def test_network_load
    network = Maightro::Domain::Network.load("config.yaml")

    assert network.stations.include?("Ballina")
  end

  def test_network_segment_duration
    network = Maightro::Domain::Network.load("config.yaml")
    duration = network.segment_duration("Ballina", "Foxford")

    assert_equal 11, duration.to_minutes.round
  end

  def test_network_full_duration
    network = Maightro::Domain::Network.load("config.yaml")
    duration = network.duration("Ballina", "Westport")

    # Should be around 49-53 minutes based on config
    assert duration.to_minutes > 45
    assert duration.to_minutes < 60
  end

  def test_network_stops
    network = Maightro::Domain::Network.load("config.yaml")
    dep = Time.parse("08:00")
    stops = network.stops("Ballina", "Manulla Junction", dep)

    assert_equal 3, stops.size
    assert_equal "Ballina", stops.first[0]
    assert_equal "Manulla Junction", stops.last[0]
  end
end
