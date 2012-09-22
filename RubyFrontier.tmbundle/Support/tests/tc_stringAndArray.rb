
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

describe "String" do
  describe "dropnonalphas" do
    it "drops non alphas" do
      "a big, fat: hen!".dropNonAlphas.must_equal "abigfathen"
    end
  end
end

describe "Array" do
  describe "nextprev" do
    before do
      @arr = [1, 2, 3, 4, 3, 2, 1]
      @arr2 = [5, 4, 3, 2, 1]
    end
    it "returns nil-nil if no params" do
      @arr.nextprev.must_equal [nil,nil]
    end
    it "describes first occurrence even when first element" do
      @arr.nextprev(1).must_equal [nil,2]
    end
    it "describes first occurrence somewhere in the middle" do
      @arr.nextprev(2).must_equal [1,3]
      @arr2.nextprev(3).must_equal [4,2]
    end
    it "describes first occurrence even when last element" do
      @arr2.nextprev(1).must_equal [2,nil]
    end
    it "accepts a block to pick out the target element" do
      @arr.nextprev{|n| n*2 == 8}.must_equal [3,3]
      # the block can return anything that isn't false or nil to mean "this element"
      @arr.nextprev{|n| n*2 == 8 ? "howdy" : false}.must_equal [3,3]
    end
    it "returns nil-nil if param not found" do
      @arr.nextprev(5).must_equal [nil,nil]
      @arr.nextprev{false}.must_equal [nil,nil]
      @arr.nextprev{nil}.must_equal [nil,nil]
    end
    it "returns nil-nil if only one element" do
      [1].nextprev(1).must_equal [nil,nil]
    end
    it "returns nil-nil if no elements" do
      [].nextprev(1).must_equal [nil,nil]
    end
    it "returns nil,nil if not found" do
      @arr.nextprev(5).must_equal [nil,nil]
    end
  end
  
  describe "crunch" do
    it "removes elements equal to previous element" do
      [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 5, 5].crunch.must_equal [1,2,3,4,5]
      [1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1].crunch.must_equal [1,2,1]
      [1, 2, 1].crunch.must_equal [1, 2, 1]
    end
    it "uses normal equality" do
      [1, 1.0].crunch.must_equal [1] # unlike uniq which uses eql? so that 1 and 1.0 are different
      # in actual fact returns [1.0], since it retains the last in the series
      [1, 1.0].crunch.must_be :eql?, [1.0]
    end
    it "handles edge cases" do
      [1].crunch.must_equal [1]
      [].crunch.must_equal []
    end
  end
end


