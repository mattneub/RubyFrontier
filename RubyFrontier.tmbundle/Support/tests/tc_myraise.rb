
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

describe "myraise" do
  before do
    @raise = proc {myraise "test"}
  end
  it "raises a RuntimeError" do
    @raise.must_raise RuntimeError
  end
  it "emits the attached message" do
    @raise.call rescue $!.message.must_equal "test"
  end
  it "has a single-level backtrace" do
    @raise.call rescue $!.backtrace.length.must_equal 1
  end
end


