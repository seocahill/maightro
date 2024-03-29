require_relative '../models/scenarios/option_2.rb'
require 'test/unit'
require_relative 'test_helpers' # adjust the path as needed to point to your helpers module

class HelperTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    @tp = TrainPath.new
  end

  def test_route_lookup
    assert_equal @tp.find_route("Ballyhaunis", "Westport")[0], [:covey_return]
    assert_equal @tp.find_route("Westport", "Ballyhaunis")[0], [:covey]
    assert_equal @tp.find_route("Ballina", "Westport")[0], [:nephin]
    assert_equal @tp.find_route("Westport", "Ballina")[0], [:nephin_return]
    assert_equal @tp.find_route("Ballyhaunis", "Ballina")[0], [:costello]
    assert_equal @tp.find_route("Ballina", "Ballyhaunis")[0], [:costello_return]
    assert_equal @tp.find_route("Ballina", "Foxford")[0], [:nephin, :costello_return]
    assert_equal @tp.find_route("Castlebar", "Westport")[0], [:nephin, :covey_return]
    refute_equal @tp.find_route("Westport", "Westport")[0], [:nephin]
  end

  def test_stops_lookup
    assert_equal @tp.find_route("Manulla Junction", "Westport")[1], ["Manulla Junction", "Castlebar", "Westport"]
    assert_equal @tp.find_route("Ballina", "Manulla Junction")[1], ["Ballina", "Foxford", "Manulla Junction"]
    assert_equal @tp.find_route("Claremorris", "Foxford")[1], ["Claremorris", "Manulla Junction", "Foxford"]
    assert_equal @tp.find_route("Ballina", "Westport")[1], ["Ballina", "Foxford", "Manulla Junction", "Castlebar", "Westport"]
    assert_equal @tp.find_route("Westport", "Ballyhaunis")[1], ["Westport", "Castlebar",  "Manulla Junction", "Claremorris", "Ballyhaunis"]
  end

  def test_time_in_mins
    row = ["Ballina", "Westport", "23:17", "00:07", "", "LDT-18"]
    assert_equal 50, @tp.distance_in_mins(*row[2..3]), "calculate times after midnight correctly"
  end
end
