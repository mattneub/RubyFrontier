require "test/unit"

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class Memoizer
  def initialize
    @memoize = true
  end
  def randy(s)
    rand
  end
  def domem(tf)
    @memoize = tf
  end
  def showcache
    @@memoized_randy
  end
  extend Memoizable
  memoize :randy
end

class Memoizer
  class << self
    def randy2(s)
      rand
    end
    extend Memoizable
    memoize :randy2
  end
end

class TestMemoize < Test::Unit::TestCase
  def test_memoize
    mem = Memoizer.new
    res = mem.randy("howdy")
    # if args are the same, result is the same
    assert_equal res, mem.randy("howdy")
    # if args are not the same, result is not the same
    assert_not_equal res, mem.randy("howdy2")
    # backdoor on-off switch
    mem.domem false
    assert_not_equal res, mem.randy("howdy")
    mem.domem true
    assert_equal res, mem.randy("howdy")
    # access original method
    assert_raises(NoMethodError) do # private
      mem.__unmemoized_randy__ "howdy"
    end
    assert_not_equal res, mem.send(:__unmemoized_randy__, "howdy") # bypass privacy
    # direct inspection of cache
    cache = mem.showcache
    assert_kind_of(Hash, cache)
    assert_equal(2, cache.length) # once for howdy, once for howdy2
    # direct access to contents of cache
    # notice that our original args have been arrayified to form key
    # contents are marshalled to prevent accidental direct mutation within cache
    assert_equal res, Marshal.load(cache[Array("howdy")])
    # also works for class methods
    res = Memoizer.randy2("howdy")
    # if args are the same, result is the same
    assert_equal res, Memoizer.randy2("howdy")
    # if args are not the same, result is not the same
    assert_not_equal res, Memoizer.randy2("howdy2")
  end
end
