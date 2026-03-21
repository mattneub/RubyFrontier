
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

# classof top-level utility

class Classof < Minitest::Spec
  describe "classof" do
    it "returns the class when handed a class" do
      expect(
        classof(Object)
      ).must_be_same_as Object
      expect(
        classof(String)
      ).must_be_same_as String
    end
    it "returns the class when handed an instance" do
      expect(
        classof(Object.new)
      ).must_be_same_as Object
      expect(
        classof("howdy")
      ).must_be_same_as String
    end
    it "returns the module when handed a module" do
      expect(
        classof(Minitest)
      ).must_be_same_as Minitest
    end
  end
end


