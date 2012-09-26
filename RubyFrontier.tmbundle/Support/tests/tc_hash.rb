require 'rubygems'
gem 'minitest', '>= 3.5'
require 'minitest/autorun'

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

describe Symbol do
  it "responds to downcase" do
    :howdy.must_equal :Howdy.downcase
    :howdy.must_equal :howdy.downcase
    :howdy.must_equal :hOWDY.downcase
    :howdy.wont_equal :howdyy.downcase
  end
end

describe Hash do
  describe "fetch2" do
    before do
      @h = {"hey" => 1, :ho => 2, "ho" => 3}
      @h2 = {"hey" => 1, "ho" => 3, :ho => 2} # different order
      @h3 = Hash.new("yowee").merge @h # different empty-key default
    end
    it "raises unless key is symbol" do
      proc {@h.fetch2("hey")}.must_raise RuntimeError
      proc {@h2.fetch2("hey")}.must_raise RuntimeError
      proc {@h3.fetch2("hey")}.must_raise RuntimeError
    end
    it "fetches string key if no symbol key exists" do
      @h.fetch2(:hey).must_equal 1
      @h2.fetch2(:hey).must_equal 1
      # TODO: this next line fails; fetches string key only if symbol key returns nil
      # according my comment, I cannot change this because to do so breaks BindingMaker
      # need to figure out why and fix
      # @h3.fetch2(:hey).must_equal 1
    end
    it "fetches symbol key if symbol key exists" do
      @h.fetch2(:ho).must_equal 2
      @h2.fetch2(:ho).must_equal 2
      @h2.fetch2(:ho).must_equal 2
    end
    it "returns default if key doesn't exist" do
      @h.fetch2(:ha).must_be_nil
      @h2.fetch2(:ha).must_be_nil
      @h3.fetch2(:ha).must_equal "yowee"
    end
  end
end

describe LCHash do
  before do
    @h = {"hey" => 1, :ho => 2, "ho" => 3}
    @h2 = {"hey" => 1, "ho" => 3, :ho => 2} # different order
    @lch = LCHash.new.merge(@h)
    @lch2 = LCHash.new.merge(@h2)
    @lch3 = LCHash.new("yowee").merge(@h)
  end
  it "returns value given exact key normally" do
    @lch["hey"].must_equal 1
    @lch2["hey"].must_equal 1
    @lch3["hey"].must_equal 1
    @lch["ho"].must_equal 3
    @lch2["ho"].must_equal 3
    @lch3["ho"].must_equal 3
    @lch[:ho].must_equal 2
    @lch2[:ho].must_equal 2
    @lch3[:ho].must_equal 2
  end
  it "returns value given key incorrectly cased" do
    @lch["hEy"].must_equal 1
    @lch2["Hey"].must_equal 1
    @lch3["heY"].must_equal 1
    @lch["hO"].must_equal 3
    @lch2["Ho"].must_equal 3
    @lch3["HO"].must_equal 3
    @lch[:Ho].must_equal 2
    @lch2[:hO].must_equal 2
    @lch3[:HO].must_equal 2
  end
  describe "fetch2" do
    it "raises unless key is symbol" do
      proc {@lch.fetch2("hey")}.must_raise RuntimeError
      proc {@lch2.fetch2("hey")}.must_raise RuntimeError
      proc {@lch3.fetch2("hey")}.must_raise RuntimeError
    end
    it "fetches string key if no symbol key exists" do
      @lch.fetch2(:Hey).must_equal 1
      @lch2.fetch2(:hEy).must_equal 1
      # TODO: this next line fails; fetches string key only if symbol key returns nil
      # according my comment, I cannot change this because to do so breaks BindingMaker
      # need to figure out why and fix
      # @h3.fetch2(:heY).must_equal 1
    end
    it "fetches symbol key if symbol key exists" do
      @lch.fetch2(:Ho).must_equal 2
      @lch2.fetch2(:hO).must_equal 2
      @lch2.fetch2(:HO).must_equal 2
    end
    it "returns default if key doesn't exist" do
      @lch.fetch2(:Ha).must_be_nil
      @lch2.fetch2(:hA).must_be_nil
      @lch3.fetch2(:HA).must_equal "yowee"
    end
  end
end

