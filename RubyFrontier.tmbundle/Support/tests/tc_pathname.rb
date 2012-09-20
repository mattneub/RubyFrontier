
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

myrequire 'rubygems', 'dimensions'

begin
  require "minitest/autorun"
rescue LoadError
  require 'rubygems'
  require 'minitest/autorun'
end

require 'tmpdir'

describe Pathname do
  
  describe "contains" do
    it "returns true if path 1 is start of path 2" do
      p = Pathname.new("/a/b/c")
      p2 = Pathname.new("/a/b/c/d/e")
      p.contains?(p2).must_equal true
      # does final slash matter?
      p = Pathname.new("/a/b/c/")
      p.contains?(p2).must_equal true
    end
    it "returns nil if path 1 is not start of path 2" do
      p = Pathname.new("/a/b/c")
      p2 = Pathname.new("/a/b/c/d/e")
      p2.contains?(p).must_be_nil
    end
  end
  
  describe "simplename" do
    it "strips suffix from basename" do
      p = Pathname.new("a/b/c.crud")
      p.simplename.must_equal Pathname("c")
    end
  end
  
  describe "needs_update_from one file nonexistent" do
    before do
      # fixture: need one file
      tmp = Dir.tmpdir
      @f1 = tmp + "a.txt"
      File.open(@f1, "w") {|io| io.puts "howdy"}
      @f2 = tmp + "b.txt"
    end
    after do
      File.delete(@f1)
    end
    it "returns true if target file doesn't exist" do
      Pathname(@f2).exist?.must_equal false
      Pathname(@f1).exist?.must_equal true
      Pathname(@f2).needs_update_from(Pathname(@f1)).must_equal true
    end
    it "raises if source file doesn't exist" do
      Pathname(@f2).exist?.must_equal false
      Pathname(@f1).exist?.must_equal true
      p = proc {Pathname(@f1).needs_update_from(Pathname(@f2))}
      p.must_raise Errno::ENOENT
    end
  end
  
  describe "needs_update_from both files exist" do
    before do
      skip
      # fixture: need two files, one newer
      tmp = Dir.tmpdir
      @f1 = tmp + "a.txt"
      File.open(@f1, "w") {|io| io.puts "howdy"}
      sleep(2) # gotta sleep or the two mtime values will be identical
      @f2 = tmp + "b.txt"
      File.open(@f2, "w") {|io| io.puts "howdy"}
    end
    after do
      skip
      File.delete(@f1)
      File.delete(@f2)
    end
    it "returns true iff source file is newer" do
      skip
      Pathname(@f1).exist?.must_equal true
      Pathname(@f2).exist?.must_equal true
      Pathname(@f1).needs_update_from(Pathname(@f2)).must_equal true
      Pathname(@f2).needs_update_from(Pathname(@f1)).must_equal false
    end
  end
  
  describe "relative_uri_from" do
    it "raises if one or both pathnames not absolute" do
      proc {Pathname("test1").relative_uri_from(Pathname("test2"))}.must_raise RuntimeError
      proc {Pathname("/test1").relative_uri_from(Pathname("test2"))}.must_raise RuntimeError
      proc {Pathname("test1").relative_uri_from(Pathname("/test2"))}.must_raise RuntimeError
    end
    it "goes sideways" do
      Pathname("/top/test2.txt").relative_uri_from(Pathname("/top/test1.txt")).must_equal "test2.txt"
      Pathname("/top/next/test2.txt").relative_uri_from(Pathname("/top/next/test1.txt")).must_equal "test2.txt"
    end
    it "goes up with double dots" do
      Pathname("/top/down").relative_uri_from(Pathname("/top/down/test1.txt")).must_equal "../down"
      # trailing slash on first doesn't matter
      Pathname("/top/down/").relative_uri_from(Pathname("/top/down/test1.txt")).must_equal "../down"
      # trailing slash on second doesn't matter
      Pathname("/top/down").relative_uri_from(Pathname("/top/down/test1/")).must_equal "../down"
      # trailing slash on both doesn't matter
      Pathname("/top/down/").relative_uri_from(Pathname("/top/down/test1/")).must_equal "../down"
    end
    it "goes up with double dots and then sideways" do
      Pathname("/top/side").relative_uri_from(Pathname("/top/down/down/test1.txt")).must_equal "../../side"
      # trailing slash on first doesn't matter
      Pathname("/top/side/").relative_uri_from(Pathname("/top/down/down/test1.txt")).must_equal "../../side"
      # trailing slash on second doesn't matter
      Pathname("/top/side").relative_uri_from(Pathname("/top/down/down/test1/")).must_equal "../../side"
      # trailing slash on both doesn't matter
      Pathname("/top/side/").relative_uri_from(Pathname("/top/down/down/test1/")).must_equal "../../side"
    end
    it "goes down" do
      Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top")).must_equal "down/test2.txt"
      Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/down")).must_equal "down/test2.txt"
      Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/down")).must_equal "down/down/test2.txt"
      # slashes don't matter
      Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/down/")).must_equal "down/test2.txt"
      Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/down/")).must_equal "down/down/test2.txt"
      Pathname("/top/down/test2/").relative_uri_from(Pathname("/top/down/")).must_equal "down/test2"
      Pathname("/top/down/down/test2/").relative_uri_from(Pathname("/top/down/")).must_equal "down/down/test2"
    end
    it "goes sideways and down" do
      Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/test1.txt")).must_equal "down/test2.txt"
      Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/test1.txt")).must_equal "down/down/test2.txt"
      Pathname("/top/two/down/test2.txt").relative_uri_from(Pathname("/top/two/test1.txt")).must_equal "down/test2.txt"
      Pathname("/top/two/down/down/test2.txt").relative_uri_from(Pathname("/top/two/test1.txt")).must_equal "down/down/test2.txt"
    end
    it "goes way up, sideways, and down" do
      Pathname("/top/right/down/test2.txt").relative_uri_from(Pathname("/top/left/down/test1.txt")).must_equal "../../right/down/test2.txt"
    end
    it "does URL escaping" do
      Pathname("/top/down down/test2.txt").relative_uri_from(Pathname("/top/test1.txt")).must_equal "down%20down/test2.txt"
    end
    it "never mentions the top-level folder's name" do
      Pathname("/top/").relative_uri_from(Pathname("/top/text1.txt")).must_equal "./"
      Pathname("/top").relative_uri_from(Pathname("/top/down/test1.txt")).must_equal "../"
      Pathname("/top/").relative_uri_from(Pathname("/top/down/test1.txt")).must_equal "../"
      Pathname("/top").relative_uri_from(Pathname("/top/down/test1/")).must_equal "../"
      Pathname("/top/").relative_uri_from(Pathname("/top/down/test1/")).must_equal "../"
      Pathname("/top/").relative_uri_from(Pathname("/top/down/down/test1/")).must_equal "../../"
      Pathname("/top").relative_uri_from(Pathname("/top/down/down/test1.txt")).must_equal "../../"
      Pathname("/top").relative_uri_from(Pathname("/top/down/down/test1")).must_equal "../../"
    end
  end
  
  describe "image_size" do
    it "measures dimensions of gifs jpgs pngs and tiffs" do
      p = Pathname(__FILE__).dirname + "images"
      (p + "im.gif").image_size.must_equal [372,37]
      (p + "im.jpg").image_size.must_equal [372,37]
      (p + "im.png").image_size.must_equal [372,37]
      (p + "im.tif").image_size.must_equal [372,37]
      (p + "im.pct").image_size.must_equal [nil,nil] # we don't do PICT
    end
  end
  
  describe "chop_basename" do
    it "memoizes" do
      p = Pathname("yoho")
      p.chop_basename("/hey/howdy/there.txt").must_equal ["/hey/howdy/", "there.txt"]
      # peep inside Pathname class and see that we are memoizing as expected
      h = Pathname.send :class_variable_get, :@@memoized_chop_basename
      Marshal.load(h[Array("/hey/howdy/there.txt")]).must_equal ["/hey/howdy/", "there.txt"]
    end
  end

end


