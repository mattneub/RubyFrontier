
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

# class/instance method memoize

# use classes to create separate namespaces
# this gives us an easy way to set up stub classes

# each "describe" makes a class, I think, but it could be all the same class
# so, to be certain they are all separate, we use separate classes

# note that each "it" test creates an instance using "before"
# so there are separate instances with separate instance variables for each "it"
# however, that is very low overhead here

class MemoizeClassMethod < Minitest::Spec
  # let's memoize a class method
  class Memoizer
    class << self
      def randy2(s)
        rand
      end
      extend Memoizable
      memoize :randy2
    end
  end

  describe "memoization of a class method" do
    before do
      # let's obtain a memoized result
      @origarg = "howdy"
      @randy2memoized = Memoizer.randy2(@origarg)
    end
  
    it "gives memoized result if args are the same" do
      expect(
        Memoizer.randy2(@origarg)
      ).must_equal @randy2memoized
    end
    it "gives a different result if args are not the same" do
      expect(
        Memoizer.randy2(@origarg + "not")
      ).wont_equal @randy2memoized
    end
  end
end

class MemoizeModuleMethod < Minitest::Spec
  module Memoizer
    class << self
      def randy3(s)
        rand
      end
      extend Memoizable
      memoize :randy3
    end
  end
  describe "memoization of a module method" do
    before do
      # let's obtain a memoized result
      @origarg = "howdy"
      @randy3memoized = Memoizer.randy3(@origarg)
    end
    it "gives memoized result if args are the same" do
      expect(
        Memoizer.randy3(@origarg)
      ).must_equal @randy3memoized
    end
    it "gives a different result if args are not the same" do
      expect(
        Memoizer.randy3(@origarg + "not")
      ).wont_equal @randy3memoized
    end
  end
end

class MemoizeInstanceMethod < Minitest::Spec
  # let's memoize an instance method
  class Memoizer
    def randy(s)
      rand
    end
    extend Memoizable
    memoize :randy
  end

  describe "memoization of an instance method" do
    before do
      # let's make an instance and obtain a memoized result
      @mem = Memoizer.new
      @origarg = "howdy"
      @randymemoized = @mem.randy(@origarg)
      # here's how to peek at the cache (class_variable_get is private in Ruby 1.8)
      @the_cache = @mem.class.send :class_variable_get, :@@memoized_randy
    end
  
    it "gives memoized result if args are the same" do
      expect(
        @mem.randy(@origarg)
      ).must_equal @randymemoized
      expect(
        @mem.randy(@origarg)
      ).must_equal @mem.randy(@origarg)
    end
    it "gives a different result if args are not the same" do
      expect(
        @mem.randy(@origarg + "not")
      ).wont_equal @randymemoized
    end
    it "gives a different result if args are the same but backdoor switch is turned off" do
      @mem.instance_variable_set :@memoize, false
      expect(
        @mem.randy(@origarg)
      ).wont_equal @randymemoized
      expect(
        @mem.randy(@origarg)
      ).wont_equal @mem.randy(@origarg)
      # setting to nil is like setting to true, it turns the backdoor switch back on
      @mem.instance_variable_set :@memoize, nil
      expect(
        @mem.randy(@origarg)
      ).must_equal @randymemoized
      expect(
        @mem.randy(@origarg)
      ).must_equal @mem.randy(@origarg)
      @mem.instance_variable_set :@memoize, true
      expect(
        @mem.randy(@origarg)
      ).must_equal @randymemoized
      expect(
        @mem.randy(@origarg)
      ).must_equal @mem.randy(@origarg)
    end
  
    it "has privatized the original method" do
      privateMethodCall = proc {@mem.__unmemoized_randy__ @origarg}
      expect(
        privateMethodCall
      ).must_raise NoMethodError
      expect(
        (privateMethodCall.call rescue $!.message)
      ).must_match(/private/)
      # but of course we can bypass that privacy using send
      privateMethodSend = proc {@mem.send :__unmemoized_randy__, @origarg}
      expect(
        privateMethodSend.call
      ).wont_equal privateMethodSend.call
    end
  
    it "caches in a hash" do
      expect(
        @the_cache
      ).must_be_instance_of Hash
    end
    describe "details of the hash" do
      it "keys on array of args" do
        expect(
          @the_cache.fetch(Array(@origarg))
        ).wont_be_nil
      end
      it "marshals the value" do
        expect(
          Marshal.load(@the_cache[Array(@origarg)])
        ).must_equal @mem.randy(@origarg)
      end
    end
  end
end

