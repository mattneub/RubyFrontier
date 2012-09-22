
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourney.rb'

begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

describe "globals" do
  describe "usertemplates" do
    it "is defined and points to standard templates" do
      $usertemplates.wont_be_nil
      ($usertemplates + "bbedit.txt").exist?.must_equal true
      ($usertemplates + "white.txt").exist?.must_equal true
    end
  end
  describe "newsite" do
    it "is defined and points to model site" do
      $newsite.wont_be_nil
      ($newsite + "firstpage.txt").exist?.must_equal true
    end
  end
end

describe UserLand::Html do
  it "class methods exist" do
    UserLand::Html.respond_to?(:guaranteePageOfSite).must_equal true
  end
  it "standard macros instance methods exist" do
    UserLand::Html::StandardMacros.method_defined?(:linkstylesheet).must_equal true
  end
  describe UserLand::Html::PageMaker do
    it "includes standard macros instance methods" do
      UserLand::Html::PageMaker.method_defined?(:linkstylesheet).must_equal true
    end
  end
end

