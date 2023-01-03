require_relative '../models/scenarios/option_2.rb'
require 'test/unit'

class Option2Test < Test::Unit::TestCase

  def setup
    @rows = Option2.new.rows
  end

  def test_results_length
    assert_equal @rows.length, 21
  end
end
