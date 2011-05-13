require 'test/unit'

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourney.rb'

class TestFakeStdout < Test::Unit::TestCase
  def test_usertemplates_newsite
    assert_not_equal(nil, $usertemplates)
    assert(($usertemplates + "bbedit.txt").exist?)
    assert(($usertemplates + "white.txt").exist?)
    assert_not_equal(nil, $newsite)
    assert(($newsite + "firstpage.txt").exist?)
  end
  def test_classesLoaded
    # PageMaker class was created
    assert_nothing_raised do
      UserLand::Html::PageMaker
    end
    # Html class methods were created
    assert(UserLand::Html.respond_to?(:guaranteePageOfSite))
    # standard macros were created
    assert(UserLand::Html::StandardMacros.method_defined?(:linkstylesheet))
    # standard macros were included in PageMaker
    assert(UserLand::Html::PageMaker.method_defined?(:linkstylesheet))
  end
end