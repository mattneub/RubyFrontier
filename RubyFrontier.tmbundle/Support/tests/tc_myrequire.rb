
require "test/unit"

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

class TestMyRequire < Test::Unit::TestCase
  def test_myrequire
    # simple require of one library
    assert_nothing_raised do
      myrequire 'pathname'
      Pathname
    end
    # require of multiple libraries in implicit array
    assert_nothing_raised do
      myrequire 'pathname', 'yaml'
      Pathname
      YAML
    end
    # require of multiple libraries in implicit array of explicit one-element arrays
    assert_nothing_raised do
      myrequire ['pathname'], ['yaml']
      Pathname
      YAML
    end
    # require of multiple libraries in explicit array splatted
    assert_nothing_raised do
      myrequire *['pathname', 'yaml']
      Pathname
      YAML
    end
    # require of library plus include
    assert_nothing_raised do
      myrequire ['yaml', :YAML]
      YAML
      ERROR_MANY_IMPLICIT
    end
  end
end

class TestMyRequireOutput < Test::Unit::TestCase
  # ability to nab stdout and inspect it as @stdout
  require (File.dirname(__FILE__)) + '/stdoutRedirectionForTesting.rb'
  include RedirectIo
  # separate defs because we want setup and teardown separately for each, to end up with a different @stdout
  # mere require of single unavailable library: no exception, warning comes back
  def test_myrequire
    assert_nothing_raised do
      myrequire 'zampabalooie'
    end
    assert_match /^Warning: Require failed/, @stdout.string, @stdout.string
  end
  # require of multiple libraries in explicit array
  # but this syntax is wrong; it is an array of one element, so 'yaml' is taken as an include, which fails
  def test_myrequire2
    assert_nothing_raised do
      myrequire ['pathname', 'yaml']
    end
    assert_match /failed to include yaml/, @stdout.string, @stdout.string
  end
  # require of multiple libraries in explicit array splatted, one bad
  def test_myrequire3
    assert_nothing_raised do
      myrequire *['pathname', 'yamlcaml']
    end
    assert_match /^Warning: Require failed/, @stdout.string, @stdout.string
  end
  # require of library plus include, with failure
  def test_myrequire4
    assert_nothing_raised do
      myrequire ['yaml', :YAMLL]
    end
    assert_match /failed to include/, @stdout.string, @stdout.string
  end
end

=begin
require 'test/unit/ui/console/testrunner'
class TestMyRequireSuite
  def self.suite
    suite = Test::Unit::TestSuite.new "TestMyRequire"
    suite << TestMyRequire.suite
    suite << TestMyRequireOutput.suite
    return suite
  end
end
Test::Unit::UI::Console::TestRunner.run(TestMyRequireSuite)
=end


