
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourney.rb'

require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

describe "globals" do
  describe "usertemplates" do
    it "is defined and points to standard templates" do
      expect(
        $usertemplates
      ).wont_be_nil
      expect(
        $usertemplates + "bbedit.txt"
      ).path_must_exist
      expect(
        $usertemplates + "white.txt"
      ).path_must_exist true
    end
  end
  describe "newsite" do
    it "is defined and points to model site" do
      expect(
        $newsite
      ).wont_be_nil
      expect(
        $newsite + "firstpage.txt"
      ).path_must_exist true
    end
  end
end

describe UserLand::Html do
  it "class methods exist" do
    expect(
      UserLand::Html
    ).must_respond_to :guaranteePageOfSite
  end
  it "standard macros instance methods exist" do
    expect(
      UserLand::Html::StandardMacros.method_defined?(:linkstylesheet)
    ).must_equal true
  end
  describe UserLand::Html::PageMaker do
    it "includes standard macros instance methods" do
      expect(
        UserLand::Html::PageMaker.method_defined?(:linkstylesheet)
      ).must_equal true
    end
  end
end

