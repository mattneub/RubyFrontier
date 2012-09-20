

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'
$: << File.dirname(File.expand_path(__FILE__)) + '/thingsToRequire'

begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

class TestMyRequire < MiniTest::Spec
  # assert_nothing_raised is accused of being not a test at all 
  # (http://blog.zenspider.com/blog/2012/01/assert_nothing_tested.html)
  # so it has been removed in the conversion from Test::Unit to MiniTest
  # it is argued that if something raises, it will raise right there in the test
  # (https://github.com/seattlerb/minitest/issues/159)
  # nevertheless it's nice to have an actual assertion
  # hence this utility whose output can be tested
  def testForError # pass me a block and I'll tell you if it raised
    yield
    "ok"
  rescue
    $!
  end
  before do
    # make sure we are actually requiring/loading something new each time
    # note that "before" can include an assertion!
    proc{Req1}.must_raise NameError
    proc{Req2}.must_raise NameError
  end
  after do
    # "unload" what we required/loaded, by removing the name and the require path
    begin
      Object.send :remove_const, :Req1
      Object.send :remove_const, :Req2
    rescue
    end
    $".delete_if {|elem| elem =~ %r%thingsToRequire% }
  end
  it "requires one library" do
    testForError do
      myrequire 'req1'
      Req1
    end.must_equal "ok"
  end
  it "requires multiple libraries in implicit array" do
    testForError do
      myrequire 'req1', 'req2'
      Req1
      Req2
    end.must_equal "ok"
  end
  it "requires multiple libraries in implicit array of explicit one-element arrays" do
    testForError do
      myrequire ['req1'], ['req2']
      Req1
      Req2
    end.must_equal "ok"
  end
  it "requires multiple libraries in explicit array splatted" do
    testForError do
      myrequire *['req1', 'req2']
      Req1
      Req2
    end.must_equal "ok"
  end
  it "treats two-element array as signifying library and namespace" do
    out, err = capture_io do 
      myrequire ['req1', 'req2']
    end
    out.must_match %r/failed to include req2/
  end
  it "successfully includes namespaces in series" do
    proc {Three}.must_raise NameError # because there is no such term
    # but...
    testForError do
      myrequire(['req1', [:Req1, :Two]])
    end.must_equal "ok"
    (Three).to_s.must_equal "Req1::Two::Three"
  end
  it "complains if the require fails" do
    out, err = capture_io do
      myrequire 'req3'
    end
    out.must_match(/^Warning: Require failed.*req3/m)
  end
  it "complains if any require fails in a series" do
    out, err = capture_io do
      myrequire 'req1', 'req3', 'req2'
    end
    out.must_match(/^Warning: Require failed.*req3/m)
  end
end


