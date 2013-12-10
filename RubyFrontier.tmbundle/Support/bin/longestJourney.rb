#!/usr/bin/env ruby

# require built-in utils for outputting html
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview.rb"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape.rb"
#require "#{ENV["TM_SUPPORT_PATH"]}/lib/exit_codes.rb"

=begin
if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end
if RUBY_VERSION =~ /2.0/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end
=end


# trampoline for html-output commands
# they call RubyFrontier::perform (syntax is :method_name, trueOrFalse, argsForMethodCall...)
# we interpose our fake stdout and then do the require and call UserLand.Html
module RubyFrontier
  # utility for making nice pre output where we say "puts" (actually two "write" calls)
  # use with "open"; on init, substitutes itself for stdout, then runs block, then on close undoes the substitution
  # by inserting <br> we keep the messages flowing to the HTML window
  class FakeStdout
    def self.open
      fs = self.new
      yield
    rescue Exception => e
      puts e.message
      e.backtrace.each {|line| puts line}
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
      @old_stdout.flush # experimental
    end
    def close
      $stdout = @old_stdout
    end
    def flush
      @old_stdout.flush
    end
    def <<(what) # needed by pp
      @old_stdout.<<(what.gsub("<","&lt;")) 
      # TODO: this is incomplete, probably needs to act more like write
      # in fact I suspect that I probably could just *call* write
    end
  end
  
  def self.perform(command_name, *args)
    as_html = args.shift
    if as_html
      STDOUT.sync = true
      html_header("RubyFrontier")
      puts "<pre>"
      puts "Performing command #{command_name}" # informative and in case no error
      require File.dirname(__FILE__) + "/RubyFrontier/longestJourney.rb"
      puts "</pre>"
      puts "<pre>"
      puts " " # trying to get the console to clear as soon as possible
      FakeStdout.open do
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

# moved this to *inside* self.perform in order to get formatting of warnings on load
# require File.dirname(__FILE__) + "/RubyFrontier/longestJourney.rb"

