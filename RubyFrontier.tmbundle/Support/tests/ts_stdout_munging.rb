require 'test/unit'

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/longestJourney.rb'

class TestFakeStdout < Test::Unit::TestCase
  require (File.dirname(__FILE__)) + '/stdoutRedirectionForTesting.rb'
  include RedirectIo
  
  def test_br
    RubyFrontier::FakeStdout.open do # while FakeStdout rules, "puts" gets <br> wherever "\n" occurs
      puts "howdy\nthere\nI'm Oedipus Tex"
      puts "You may have heard of my brother Rex"
    end
    assert_equal('howdy<br>there<br>I\'m Oedipus Tex<br>You may have heard of my brother Rex<br>', @stdout.string)
  end
  def test_link
    RubyFrontier::FakeStdout.open do # while FakeStdout rules, line-end single-quoted filename (starts with slash) becomes a link
      puts "this is a '/cool/test'"
    end
    assert_equal('this is a <a href="txmt://open?url=file:///cool/test">/cool/test</a><br>', @stdout.string)
  end
  def test_link_not
    RubyFrontier::FakeStdout.open do # not line-final so no link
      puts "this is a '/cool/test' "
    end
    assert_equal('this is a \'/cool/test\' <br>', @stdout.string)
  end
  def test_link_not2
    RubyFrontier::FakeStdout.open do # no single-quotes so no link
      puts "this is a \"/cool/test\""
    end
    assert_equal('this is a "/cool/test"<br>', @stdout.string)
  end
  def test_link_not3
    RubyFrontier::FakeStdout.open do # no initial slash so no link
      puts "this is a 'cool/test'"
    end
    assert_equal('this is a \'cool/test\'<br>', @stdout.string)
  end
  def test_raise
    RubyFrontier::FakeStdout.open do # while FakeStdout rules, nice reformatted output of exception reports
      raise "oops"
    end
    assert_match(/^oops<br>/, @stdout.string, @stdout.string)
    assert_match(%r{RubyFrontier.tmbundle/Support/tests/ts_stdout_munging.rb:\d*:in `test_raise'<br>}, @stdout.string, @stdout.string)
  end
  def test_perform
    RubyFrontier.perform(:test_output, true) # artificial method I created just so we could test fully formatted output
    # perform with true gives us full html header and footer with <pre> sandwich around munged puts output
    # a complication: if we get the "no user.rb" message, "this is test" won't be first within the <pre> 
    assert_match(%r{(<pre>\n|<br>)this is a test<br>and this is a test<br></pre>}, @stdout.string, @stdout.string)
  end
  def test_perform2
    RubyFrontier.perform(:test_output, false) # when false, no munging of "puts", no header and footer, no nothing
    assert_equal("this is a test\nand this is a test\n", @stdout.string)
  end
  def test_perform_raise
    RubyFrontier.perform(:test_raise, true) # artificial method I created just so we could test fully formatted output when there's an exception
    assert_match(/^oops<br>/, @stdout.string, @stdout.string)
    assert_match(%r{RubyFrontier.tmbundle/Support/bin/RubyFrontier/longestJourney/userland_class_methods.rb:\d*:in `test_raise'<br>}, @stdout.string, @stdout.string)
  end
end

