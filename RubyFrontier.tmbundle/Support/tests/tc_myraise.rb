require "test/unit"

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class TestMyRaise < Test::Unit::TestCase
  # simple require of one library
  def deeper
    myraise "test"
  end
  def test_myrequire1
    assert_raise(RuntimeError) do
      deeper
    end
  end
  def test_myrequire2
    begin
      deeper
    rescue
      assert_equal "test", $!.message
      assert_equal 1, $!.backtrace.length
    end
  end
end

