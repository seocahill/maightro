require_relative '../models/scenarios/option_3.rb'
require 'test/unit'
require_relative 'test_helpers'


class JourneyPlannerTest < Test::Unit::TestCase
  def setup
    # allow to hit real api to check if integration is broken
    @planner = JourneyPlanner.new(vcr_bypass: 'true')
  end

  def test_search_with_defaults
    result = @planner.search
    assert_kind_of Struct, result
    assert_respond_to result, :stations
    assert_respond_to result, :trains_out
    assert_respond_to result, :trains_ret
    # Insert more assertions to check the structure and data integrity if needed
  end
end
