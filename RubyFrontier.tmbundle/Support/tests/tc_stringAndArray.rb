require "test/unit"

require File.dirname(File.dirname(__FILE__)) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class TestStringAndArray < Test::Unit::TestCase
  def test_dropnon
    assert_equal("abigfathen", "a big, fat: hen!".dropNonAlphas)
  end
  def test_nextprev
    arr = [1, 2, 3, 4, 3, 2, 1]
    arr2 = [5, 4, 3, 2, 1]
    assert_equal([nil, nil], arr.nextprev) # no params
    assert_equal([nil, 2], arr.nextprev(1)) # first occurrence, first edge case
    assert_equal([1,3], arr.nextprev(2)) # first occurrence, middle case
    assert_equal([4,2], arr2.nextprev(3)) # middle case
    assert_equal([2,nil], arr2.nextprev(1)) # second edge case
    assert_equal([3,3], arr.nextprev {|n| n*2 == 8}) # ok to pass a block
    assert_equal([nil, nil], [1].nextprev) # edge case
    assert_equal([nil, nil], [].nextprev) # ultimate edge case
  end
  def test_crunch
    arr = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 5, 5]
    assert_equal([1, 2, 3, 4, 5], arr.crunch)
    assert_equal([1, 2, 3], [1, 2, 3].crunch)
    assert_equal([1], [1, 1.0].crunch) # unlike uniq, which uses eql? so that 1 and 1.0 are different
    assert_equal([1,2], [1,2].crunch) # edge case
    assert_equal([1], [1, 1, 1, 1, 1].crunch)
    assert_equal([1], [1, 1, 1, 1].crunch)
    assert_equal([1], [1, 1, 1].crunch)
    assert_equal([1], [1, 1].crunch)
    assert_equal([1], [1].crunch) # edge case
    assert_equal([1, 2], [1, 1, 2, 2].crunch)
    assert_equal([], [].crunch) # ultimate edge case
  end
end
