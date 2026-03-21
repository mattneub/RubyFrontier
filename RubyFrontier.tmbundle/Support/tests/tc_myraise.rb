
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

describe "myraise" do
  before do
    @raise = proc {myraise "test"}
  end
  it "raises a RuntimeError" do
    expect(
      @raise
    ).must_raise RuntimeError
  end
  it "emits the attached message" do
    expect(
      (@raise.call rescue $!.message)
    ).must_equal "test"
  end
  it "has a single-level backtrace" do
    expect(
      (@raise.call rescue $!.backtrace.length)
    ).must_equal 1
  end
end


