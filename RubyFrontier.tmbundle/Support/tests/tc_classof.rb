
require "test/unit"

require File.dirname(File.dirname(__FILE__)) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class TestClassof < Test::Unit::TestCase
  def test_classof
    assert_equal Object, classof(Object)
    assert_equal Object, classof(Object.new)
    assert_equal TestClassof, classof(self)
    assert_equal TestClassof, classof(self.class)
  end
end