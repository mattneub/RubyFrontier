require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

describe Symbol do
  it "responds to downcase" do
    expect(:howdy).must_equal :Howdy.downcase
    expect(:howdy).must_equal :howdy.downcase
    expect(:howdy).must_equal :hOWDY.downcase
    expect(:howdy).wont_equal :howdyy.downcase
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
      expect{
        @h.fetch2("hey")
      }.must_raise RuntimeError
      expect{
        @h2.fetch2("hey")
      }.must_raise RuntimeError
      expect{
        @h3.fetch2("hey")
      }.must_raise RuntimeError
    end
    it "fetches string key if no symbol key exists" do
      expect(
        @h.fetch2(:hey)
      ).must_equal 1
      expect(
        @h2.fetch2(:hey)
      ).must_equal 1
      # TODO: this next line fails; fetches string key only if symbol key returns nil
      # according my comment, I cannot change this because to do so breaks BindingMaker
      # need to figure out why and fix
      # @h3.fetch2(:hey).must_equal 1
    end
    it "fetches symbol key if symbol key exists" do
      expect(
        @h.fetch2(:ho)
      ).must_equal 2
      expect(
        @h2.fetch2(:ho)
      ).must_equal 2
      expect(
        @h2.fetch2(:ho)
      ).must_equal 2
    end
    it "returns default if key doesn't exist" do
      expect(
        @h.fetch2(:ha)
      ).must_be_nil
      expect(
        @h2.fetch2(:ha)
      ).must_be_nil
      expect(
        @h3.fetch2(:ha)
      ).must_equal "yowee"
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
    expect(
      @lch["hey"]
    ).must_equal 1
    expect(
      @lch2["hey"]
    ).must_equal 1
    expect(
      @lch3["hey"]
    ).must_equal 1
    expect(
      @lch["ho"]
    ).must_equal 3
    expect(
      @lch2["ho"]
    ).must_equal 3
    expect(
      @lch3["ho"]
    ).must_equal 3
    expect(
      @lch[:ho]
    ).must_equal 2
    expect(
      @lch2[:ho]
    ).must_equal 2
    expect(
      @lch3[:ho]
    ).must_equal 2
  end
  it "returns value given key incorrectly cased" do
    expect(
      @lch["hEy"]
    ).must_equal 1
    expect(
      @lch2["Hey"]
    ).must_equal 1
    expect(
      @lch3["heY"]
    ).must_equal 1
    expect(
      @lch["hO"]
    ).must_equal 3
    expect(
      @lch2["Ho"]
    ).must_equal 3
    expect(
      @lch3["HO"]
    ).must_equal 3
    expect(
      @lch[:Ho]
    ).must_equal 2
    expect(
      @lch2[:hO]
    ).must_equal 2
    expect(
      @lch3[:HO]
    ).must_equal 2
  end
  describe "fetch2" do
    it "raises unless key is symbol" do
      expect{
        @lch.fetch2("hey")
      }.must_raise RuntimeError
      expect{
        @lch2.fetch2("hey")
      }.must_raise RuntimeError
      expect{
        @lch3.fetch2("hey")
      }.must_raise RuntimeError
    end
    it "fetches string key if no symbol key exists" do
      expect(
        @lch.fetch2(:Hey)
      ).must_equal 1
      expect(
        @lch2.fetch2(:hEy)
      ).must_equal 1
      # TODO: this next line fails; fetches string key only if symbol key returns nil
      # according my comment, I cannot change this because to do so breaks BindingMaker
      # need to figure out why and fix
      # @h3.fetch2(:heY).must_equal 1
    end
    it "fetches symbol key if symbol key exists" do
      expect(
        @lch.fetch2(:Ho)
      ).must_equal 2
      expect(
        @lch2.fetch2(:hO)
      ).must_equal 2
      expect(
        @lch2.fetch2(:HO)
      ).must_equal 2
    end
    it "returns default if key doesn't exist" do
      expect(
        @lch.fetch2(:Ha)
      ).must_be_nil
      expect(
        @lch2.fetch2(:hA)
      ).must_be_nil
      expect(
        @lch3.fetch2(:HA)
      ).must_equal "yowee"
    end
  end
end

