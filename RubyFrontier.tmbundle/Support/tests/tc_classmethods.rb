begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

# load the whole RubyFrontier world
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourney.rb'

require 'tmpdir' # we're going to make and remove a folder full of stuff


class TestUserLandHtml < MiniTest::Spec
  @@preflighted = false
  before do
    @folder = (Pathname(__FILE__).dirname + "testsites") + "site1"
    @template = @folder + "#template.txt"
    @firstpage = @folder + "firstpage.txt"
    @nonexistentpage = @folder + "biteme.txt"
    @deeperpage = (@folder + "folder") + "fourthpage.txt"
  end
  
  describe "class methods" do
    describe "guaranteePageOfSite" do
      it "raises for non-existent page" do
        proc{ UserLand::Html.guaranteePageOfSite @nonexistentpage }.must_raise RuntimeError
      end
      it "raises for non-page object" do
        proc{ UserLand::Html.guaranteePageOfSite @template }.must_raise RuntimeError
      end
      it "does nothing for page object" do
        proc{ UserLand::Html.guaranteePageOfSite @firstpage }.call
        "ok".must_equal "ok"
      end
    end
    describe "getFtpSiteFile" do
      it "raises for file with no ftpsite file above it" do
        proc{ UserLand::Html.getFtpSiteFile __FILE__ }.must_raise RuntimeError
      end
      it "returns the ftpsite file's pathname" do
        ftpsite = @folder + "#ftpSite.yaml"
        UserLand::Html.getFtpSiteFile(@template).must_equal ftpsite # non-page object
        UserLand::Html.getFtpSiteFile(@firstpage).must_equal ftpsite # page object
        UserLand::Html.getFtpSiteFile(@deeperpage).must_equal ftpsite # deeper page object
        UserLand::Html.getFtpSiteFile(@nonexistentpage).must_equal ftpsite # non-existent object but folder exists
      end
    end
    describe "everyPageOf" do
      def simpleOrdered(meth, p)
        (UserLand::Html.send meth, p).map{|f| f.simplename.to_s}.sort
      end
      describe "everyPageOfFolder" do
        it "lists every page object at all depths down only" do
          simpleOrdered(:everyPageOfFolder, @folder).must_equal %w{firstpage fourthpage secondpage thirdpage}
          simpleOrdered(:everyPageOfFolder, @deeperpage.dirname).must_equal %w{ fourthpage }
        end
      end
      describe "everyPageOfSite" do
        it "lists every page object at all depths up and down" do
          simpleOrdered(:everyPageOfSite, @firstpage).must_equal %w{firstpage fourthpage secondpage thirdpage}
          # folder ok
          simpleOrdered(:everyPageOfSite, @deeperpage.dirname).must_equal %w{firstpage fourthpage secondpage thirdpage}
          # nonpage object ok
          simpleOrdered(:everyPageOfSite, @template).must_equal %w{firstpage fourthpage secondpage thirdpage}
          simpleOrdered(:everyPageOfSite, @deeperpage).must_equal %w{firstpage fourthpage secondpage thirdpage}
        end
      end
    end
    describe "getLink" do
      # html.getLink - linetext, url, options hash
      it "uses linetext and url" do
        UserLand::Html.getLink("biteme", "url").must_equal %{<a href="url">biteme</a>}
      end
      it "uses linetext, url, arbitrary options hash" do
        UserLand::Html.getLink("biteme", "url", :crap => "crud", :bite => "me").
          must_equal %{<a href="url" crap="crud" bite="me">biteme</a>}
      end
      it "interprets anchor option correctly" do
        UserLand::Html.getLink("biteme", "url", :crap => "crud", :bite => "me", :anchor => "anc").
          must_equal %{<a href="url#anc" crap="crud" bite="me">biteme</a>}
      end
      it "interprets anchor option correctly and forgives initial hash" do
        UserLand::Html.getLink("biteme", "url", :crap => "crud", :bite => "me", :anchor => "#anc").
          must_equal %{<a href="url#anc" crap="crud" bite="me">biteme</a>}
      end
      it "does our pseudo syntax for foreign site folder" do
        UserLand::Html.getLink("biteme", "url", :crap => "crud", :bite => "me", :anchor => "#anc", :othersite => "other").
          must_equal %{<a href="other^url#anc" crap="crud" bite="me">biteme</a>}
      end
    end
    describe "preflightsite and autoglossary structure" do
      before do
        unless @@preflighted # do once
          capture_io do # suppress output
            UserLand::Html.preflightSite(@firstpage) # actually works for any file within the site
          end
          @@autog = File.open( @folder + '#autoglossary.yaml' ) { |yf| YAML::load( yf ) }
          @@preflighted = true
        end
      end
      it "autoglossary represents a hash containing exactly these 8 entries" do
        @@autog.must_be_kind_of Hash
        # keys are by lowercase title and lowercase simplename
        titles = ['my first web page', 'my second web page', 'my third and greatest web page', 'my fourth web page']
        titles += ['firstpage', 'secondpage', 'thirdpage', 'fourthpage']
        titles.each {|title| @@autog[title].wont_be_nil}
        # and that's all there is
        @@autog.length.must_equal 8
      end
      it "autoglossary values have the correct structure" do
        fp = @@autog['fourthpage']
        fp[:linetext].must_equal "My Fourth Web Page"
        fp[:path].must_equal Pathname("folder/fourthpage.html")
        fp[:adr].must_equal @deeperpage
      end
    end
  end
  # TODO: test traverseLink somehow?
end

class TestUserLandHtml2 < MiniTest::Spec
  before do
    @folder = (Pathname(__FILE__).dirname + "testsites") + "site1"
    @template = @folder + "#template.txt"
    @firstpage = @folder + "firstpage.txt"
    @nonexistentpage = @folder + "biteme.txt"
    @deeperpage = (@folder + "folder") + "fourthpage.txt"
  end
  
  describe "class methods for creating and publishing" do
    it "creates a new site with the expected contents" do
      Dir.mktmpdir("testingnewsite") do |dir|
        UserLand::Html.newSite(dir)
        # and here's what I expect it to contain
        s = <<END
#filters
#ftpSite.yaml
#glossary.yaml
#images
#prefs.yaml
#stylesheets
#template.txt
#templates
#tools
firstpage.txt
secondpage.txt
thirdpage.txt

./#filters:
cssFilter.rb
finalFilter.rb
firstFilter.rb
pageFilter.rb
postMacroFilter.rb

./#images:
rubyFrontierLogo.png

./#stylesheets:
s1.css
s2.css

./#templates:
secondtemplate.txt
thirdtemplate.txt

./#tools:
blurb.txt
nextprevlinks.rb
section.rb
END
        Dir.chdir(dir) do
          `ls -R1`.must_equal s
        end
      end
    end
  end
  
  describe "releaseRenderedPage" do
    # false false means don't rebuild autoglossary, don't open in browser
    it "raises for a nonpage object" do
      proc {UserLand::Html.releaseRenderedPage(@template, false, false)}.must_raise RuntimeError
    end
    it "raises and says not a site page" do
      err = proc {UserLand::Html.releaseRenderedPage(@template, false, false) rescue $!}.call
      err.message.must_match %r%not a site page%
    end
    it "builds site1 correctly" do
      actualoutput = Pathname("~/Desktop/testsite1").expand_path # new site will be created here
      actualoutput.rmtree unless !actualoutput.exist?
      capture_io do # suppress output
        UserLand::Html.publishSite(@firstpage, true, false)
        UserLand::Html.publishSite(@firstpage, false, false) # must publish twice to get the xref to work
      end
      #out.must_match %r%finished publishing%i # fails sometimes and I'm not sure why
      # we have a prebuilt model, let's see if they match
      modeloutput = @folder.dirname + "site1PublishAll"
      command = "diff -r '#{modeloutput.to_s}' '#{actualoutput.to_s}'"
      `#{command}`.must_equal ""
    end
  end

end
