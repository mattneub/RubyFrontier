
require "test/unit"

require File.dirname(File.dirname(__FILE__)) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class TestHash < Test::Unit::TestCase
  def setup
    @h = {"hey" => 1, :ho => 2, "ho" => 3}
    @h2 = LCHash.new.merge @h
  end
  def test_symbollc # symbols are downcaseable
    assert_equal(:howdy, :Howdy.downcase)
    assert_equal(:howdy, :howdy.downcase)
    assert_equal(:howdy, :hOWDY.downcase)
  end
  def test_fetch2
    assert_raises RuntimeError do
      @h.fetch2("hey") # key must be a symbol
    end
    assert_equal(1, @h.fetch2(:hey)) # symbol key fetches using string key
    assert_equal(2, @h.fetch2(:ho)) # symbol key works normally, prior to string
    assert_nil(@h.fetch2(:ha)) # non-existent key returns nil as usual
  end
  def test_lchash # LCHash: keys work even if you throw uppercase string or symbol at it
    assert_equal(1, @h2["Hey"])
    assert_equal(1, @h2["hey"])
    assert_equal(nil, @h["Hey"])
    assert_equal(2, @h2[:Ho])
    assert_equal(2, @h2[:ho])
    assert_equal(nil, @h[:Ho])
  end
end
