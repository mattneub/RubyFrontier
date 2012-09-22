begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/longestJourney.rb'

#TODO: fake stdout now does more work, need more tests

describe RubyFrontier::FakeStdout do
  it "replaces newline with br" do
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        puts "howdy\nthere\nI'm Oedipus Tex"
        puts "You may have heard of my brother Rex"
      end
    end
    out.must_equal 'howdy<br>there<br>I\'m Oedipus Tex<br>You may have heard of my brother Rex<br>'
  end
  it "turns line-end single-quoted string starting with slash to txmt link" do
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        puts "this is a '/cool/test'"
      end
    end
    out.must_equal 'this is a <a href="txmt://open?url=file:///cool/test">/cool/test</a><br>'
    out.must_match %r%txmt%
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        puts "this is a '/cool/test' "
      end
    end
    out.wont_match %r%txmt% # because it wasn't line-final
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        puts "this is a \"/cool/test\""
      end
    end
    out.wont_match %r%txmt% # because it wasn't single-quoted
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        puts "this is a 'cool/test'"
      end
    end
    out.wont_match %r%txmt% # because there's no initial slash
  end
  it "nicely formats exception reports" do
    def test_raise # just to inject "test_raise" into the error's backtrace
      raise "oops"
    end
    out, err = capture_io do
      RubyFrontier::FakeStdout.open do
        test_raise
      end
    end
    out.must_match %r%^oops<br>%
    out.must_match %r{RubyFrontier.tmbundle/Support/tests/tc_stdout_munging.rb:\d*:in `test_raise'<br>}
  end
end

describe "perform" do
  it "with true, wraps pre with FakeStdout around any output" do
    out, err = capture_io do
      RubyFrontier.perform(:test_output, true)
      # artificial method I created just so we could test fully formatted output
      # perform with true gives us full html header and footer with <pre> sandwich around munged puts output
    end
    # a complication: if we get the "no user.rb" message, "this is a test" won't be first within the <pre>
    out.must_match %r{(<pre>\s*|<br>)this is a test<br>and this is a test<br></pre>}
    # same thing if we raise, passes thru nice formatting
    out, err = capture_io do
      RubyFrontier.perform(:test_raise, true)
      # artificial method I created just so we could test fully formatted output when there's an exception
      # perform with true gives us full html header and footer with <pre> sandwich around munged puts output
    end
    out.must_match %r%^oops<br>%
    out.must_match %r{RubyFrontier.tmbundle/Support/bin/RubyFrontier/longestJourney/userland_class_methods.rb:\d*:in `test_raise'<br>}
  end
  it "with false, outputs directly unmunged" do
    out, err = capture_io do
      RubyFrontier.perform(:test_output, false)
    end
    out.must_equal "this is a test\nand this is a test\n"
  end
end


