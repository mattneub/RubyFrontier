
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

require 'rubygems'
gem 'minitest', '>= 3.5'
require 'minitest/autorun'

# classof top-level utility

class Classof < MiniTest::Unit
  describe "classof" do
    it "returns the class when handed a class" do
      classof(Object).must_be_same_as Object
      classof(String).must_be_same_as String
    end
    it "returns the class when handed an instance" do
      classof(Object.new).must_be_same_as Object
      classof("howdy").must_be_same_as String
    end
    it "returns the module when handed a module" do
      classof(MiniTest).must_be_same_as MiniTest
    end
  end
end


