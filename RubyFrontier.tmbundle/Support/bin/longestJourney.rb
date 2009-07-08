#!/usr/bin/env ruby

f = `defaults read com.neuburg.matt.rubyFrontier userrb`
$userrb = f.chomp

# require built-in utils for outputting html
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview.rb"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape.rb"
#require "#{ENV["TM_SUPPORT_PATH"]}/lib/exit_codes.rb"

# trampoline for html-output commands
# they call RubyFrontier::perform;
# we interpose our fake stdout and then do the require and call UserLand.Html
module RubyFrontier
  # utility for making nice pre output where we say "puts" (actuall two "write" calls)
  # use with "open"; on init, substitutes itself for stdout, then runs block, then on close undoes the substitution
  # by inserting <br> we keep the messages flowing to the HTML window
  class FakeStdout
    def self.open
      fs = self.new
      yield
    rescue Exception => e
      fs.close
      puts e.message
      p e.backtrace.join("<br>")
    ensure
      fs.close
    end
    def initialize(*args)
      super *args
      @old_stdout = $stdout
      $stdout = self
    end
    def write(s)
      s = htmlize(s, :no_newline_after_br => true) #s.gsub("\n", "<br>")
      s = s.gsub(%r['(/.*)'(<br>|$)]) do |ss| 
        %{<a href="txmt://open?url=file://#{e_url($1)}">#{$1}</a>#{$2}}
      end
      @old_stdout.print s
    end
    def close
      $stdout = @old_stdout
    end
  end
  
  def self.perform(command_name, *args)
    as_html = args.shift
    if as_html
      STDOUT.sync = true
      html_header("RubyFrontier")
      puts "<pre>"
      FakeStdout.open do
        require File.dirname(__FILE__) + "/RubyFrontier/longestJourney.rb"
        UserLand::Html.send(command_name, *args)
      end
      puts "</pre>"
      html_footer()
    else
      require File.dirname(__FILE__) + "/RubyFrontier/longestJourney.rb"
      UserLand::Html.send(command_name, *args)
    end
  end
end

# repeat the require without penalty
#require File.dirname(__FILE__) + "/RubyFrontier/longestJourney.rb"