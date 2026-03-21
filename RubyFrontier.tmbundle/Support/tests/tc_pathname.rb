
require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

myrequire 'rubygems', 'image_size'

require 'rubygems'
gem 'minitest', '>= 6.0.0'
require 'minitest/autorun'

require 'tmpdir'

describe Pathname do
  
  describe "contains" do
    it "returns true if path 1 is start of path 2" do
      p = Pathname.new("/a/b/c")
      p2 = Pathname.new("/a/b/c/d/e")
      expect(
        p.contains?(p2)
      ).must_equal true
      # does final slash matter?
      p = Pathname.new("/a/b/c/")
      expect(
        p.contains?(p2)
      ).must_equal true
    end
    it "returns nil if path 1 is not start of path 2" do
      p = Pathname.new("/a/b/c")
      p2 = Pathname.new("/a/b/c/d/e")
      expect(
        p2.contains?(p)
      ).must_be_nil
    end
  end
  
  describe "simplename" do
    it "strips suffix from basename" do
      p = Pathname.new("a/b/c.crud")
      expect(
        p.simplename
      ).must_equal Pathname("c")
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
      expect(
        Pathname(@f2).exist?
      ).must_equal false
      expect(
        Pathname(@f1).exist?
      ).must_equal true
      expect(
        Pathname(@f2).needs_update_from(Pathname(@f1))
      ).must_equal true
    end
    it "raises if source file doesn't exist" do
      expect(
        Pathname(@f2).exist?
      ).must_equal false
      expect(
        Pathname(@f1).exist?
      ).must_equal true
      expect{
        Pathname(@f1).needs_update_from(Pathname(@f2))
      }.must_raise Errno::ENOENT
    end
  end
  
  describe "needs_update_from both files exist" do
    before do
      # fixture: need two files, one newer
      tmp = Dir.tmpdir
      @f1 = tmp + "a.txt"
      File.open(@f1, "w") {|io| io.puts "howdy"}
      sleep(2) # gotta sleep or the two mtime values will be identical
      @f2 = tmp + "b.txt"
      File.open(@f2, "w") {|io| io.puts "howdy"}
    end
    after do
      File.delete(@f1)
      File.delete(@f2)
    end
    it "returns true iff source file is newer" do
      expect(
        Pathname(@f1).exist?
      ).must_equal true
      expect(
        Pathname(@f2).exist?
      ).must_equal true
      expect(
        Pathname(@f1).needs_update_from(Pathname(@f2))
      ).must_equal true
      expect(
        Pathname(@f2).needs_update_from(Pathname(@f1))
      ).must_equal false
    end
  end
  
  describe "pieces" do
    it "breaks pathname into pieces" do
      s = "/hey/ho/nonny/no"
      p = Pathname(s)
      expect(
        p.pieces.length
      ).must_equal 4
      expect(
        "/" + p.pieces.join("/")
      ).must_equal s
    
      s = "/hey/"
      p = Pathname(s)
      expect(
        p.pieces.length
      ).must_equal 1
      expect(
        "/" + p.pieces.join("/")
      ).must_equal "/hey" # cleaned path
    
      s = "/hey"
      p = Pathname(s)
      expect(
        p.pieces.length
      ).must_equal 1
      expect(
        "/" + p.pieces.join("/")
      ).must_equal "/hey" # cleaned path
    end
  end
  
  
  describe "relative_uri_from" do
    it "rejects nonabsolutes" do
      expect{
        Pathname("test1").relative_uri_from(Pathname("test2"))
      }.must_raise RuntimeError
      expect{
        Pathname("/test1").relative_uri_from(Pathname("test2"))
      }.must_raise RuntimeError
      expect{
        Pathname("test1").relative_uri_from(Pathname("/test2"))
      }.must_raise RuntimeError
    end
    it "rejects different top levels" do
      expect{
        Pathname("/hey/ho").relative_uri_from(Pathname("/nonny/no"))
      }.must_raise RuntimeError
    end
    
    # a serious edge case
    it "handles identical paths" do
      p1 = p2 = Pathname("/a/b/c/d")
      expect(
        p1.relative_uri_from(p2)
      ).must_equal("") # crucial to our sites that this be the way of expressing it
    end
  
    # examples derived from the URI spec, http://tools.ietf.org/html/rfc3986
    it "same except for last" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a/b/c/g").relative_uri_from(p2)
      ).must_equal("g")
    end
    it "raises on pure down" do
      # there is no such thing as a uri from a folder, so there's no "right" answer
      p2 = Pathname("/a/b/c/d")
      expect{
        Pathname("/a/b/c/d/e/f/g").relative_uri_from(p2)
      }.must_raise RuntimeError
    end
    it "sidewards and down" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a/b/c/g/h/i/j").relative_uri_from(p2)
      ).must_equal("g/h/i/j")
    end
    it "one shorter" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a/b/c").relative_uri_from(p2)
      ).must_equal "."
    end
    it "two shorter" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a/b").relative_uri_from(p2)
      ).must_equal ".."
    end
    it "many shorter" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a").relative_uri_from(p2)
      ).must_equal "../.."
    end
    it "goes up many and comes down" do
      p2 = Pathname("/a/b/c/d")
      expect(
        Pathname("/a/g").relative_uri_from(p2)
      ).must_equal "../../g"
      expect(
        Pathname("/a/g/h").relative_uri_from(p2)
      ).must_equal "../../g/h"
    end
  
    # examples I made up
    it "goes sideways" do
      expect(
        Pathname("/top/test2.txt").relative_uri_from(Pathname("/top/test1.txt"))
      ).must_equal "test2.txt"
      expect(
        Pathname("/top/next/test2.txt").relative_uri_from(Pathname("/top/next/test1.txt"))
      ).must_equal "test2.txt"
    end
    it "goes up one level with a single dot" do
      expect(
        Pathname("/top/down").relative_uri_from(Pathname("/top/down/test1.txt"))
      ).must_equal "."
      # trailing slash on first doesn't matter
      expect(
        Pathname("/top/down/").relative_uri_from(Pathname("/top/down/test1.txt"))
      ).must_equal "."
      # trailing slash on second doesn't matter
      expect(
        Pathname("/top/down").relative_uri_from(Pathname("/top/down/test1/"))
      ).must_equal "."
      # trailing slash on both doesn't matter
      expect(
        Pathname("/top/down/").relative_uri_from(Pathname("/top/down/test1/"))
      ).must_equal "."
    end
    it "goes up with double dots and then sideways" do
      expect(
        Pathname("/top/side").relative_uri_from(Pathname("/top/down/down/test1.txt"))
      ).must_equal "../../side"
      # trailing slash on first doesn't matter
      expect(
        Pathname("/top/side/").relative_uri_from(Pathname("/top/down/down/test1.txt"))
      ).must_equal "../../side"
      # trailing slash on second doesn't matter
      expect(
        Pathname("/top/side").relative_uri_from(Pathname("/top/down/down/test1/"))
      ).must_equal "../../side"
      # trailing slash on both doesn't matter
      expect(
        Pathname("/top/side/").relative_uri_from(Pathname("/top/down/down/test1/"))
      ).must_equal "../../side"
    end
    it "goes down" do
      skip # THIS TEST IS BOGUS! there is no such thing as a url from a folder
      expect(
        Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top"))
      ).must_equal "down/test2.txt"
      expect(
        Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/down"))
      ).must_equal "test2.txt"
      expect(
        Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/down"))
      ).must_equal "down/test2.txt"
      # slashes don't matter
      expect(
        Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/down/"))
      ).must_equal "test2.txt"
      expect(
        Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/down/"))
      ).must_equal "down/test2.txt"
      expect(
        Pathname("/top/down/test2/").relative_uri_from(Pathname("/top/down/"))
      ).must_equal "test2"
      expect(
        Pathname("/top/down/down/test2/").relative_uri_from(Pathname("/top/down/"))
      ).must_equal "down/test2"
    end
    it "goes sideways and down" do
      expect(
        Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/test1.txt"))
      ).must_equal "down/test2.txt"
      expect(
        Pathname("/top/down/down/test2.txt").relative_uri_from(Pathname("/top/test1.txt"))
      ).must_equal "down/down/test2.txt"
      expect(
        Pathname("/top/two/down/test2.txt").relative_uri_from(Pathname("/top/two/test1.txt"))
      ).must_equal "down/test2.txt"
      expect(
        Pathname("/top/two/down/down/test2.txt").relative_uri_from(Pathname("/top/two/test1.txt"))
      ).must_equal "down/down/test2.txt"
    end
    it "goes way up, sideways, and down" do
      expect(
        Pathname("/top/right/down/test2.txt").relative_uri_from(Pathname("/top/left/down/test1.txt"))
      ).must_equal "../../right/down/test2.txt"
    end
    it "does URL escaping" do
      expect(
        Pathname("/top/down down/test2.txt").relative_uri_from(Pathname("/top/test1.txt"))
      ).must_equal "down%20down/test2.txt"
    end
    it "never mentions the top-level folder's name" do
      expect(
        Pathname("/top/").relative_uri_from(Pathname("/top/text1.txt"))
      ).must_equal "."
      expect(
        Pathname("/top").relative_uri_from(Pathname("/top/down/test1.txt"))
      ).must_equal ".."
      expect(
        Pathname("/top/").relative_uri_from(Pathname("/top/down/test1.txt"))
      ).must_equal ".."
      expect(
        Pathname("/top").relative_uri_from(Pathname("/top/down/test1/"))
      ).must_equal ".."
      expect(
        Pathname("/top/").relative_uri_from(Pathname("/top/down/test1/"))
      ).must_equal ".."
      expect(
        Pathname("/top/").relative_uri_from(Pathname("/top/down/down/test1/"))
      ).must_equal "../.."
      expect(
        Pathname("/top").relative_uri_from(Pathname("/top/down/down/test1.txt"))
      ).must_equal "../.."
      expect(
        Pathname("/top").relative_uri_from(Pathname("/top/down/down/test1"))
      ).must_equal "../.."
    end
  end
  
  describe "image_size" do
    it "measures dimensions of gifs jpgs pngs and tiffs" do
      p = Pathname(__FILE__).dirname + "images"
      expect(
        (p + "im.gif").image_size
      ).must_equal [372,37]
      expect(
        (p + "im.jpg").image_size
      ).must_equal [372,37]
      expect(
        (p + "im.png").image_size
      ).must_equal [372,37]
      expect(
        (p + "im.tif").image_size
      ).must_equal [372,37]
      expect(
        (p + "im.pct").image_size
      ).must_equal [nil,nil] # we don't do PICT
    end
  end
  
  describe "chop_basename" do
    it "memoizes" do
      p = Pathname("yoho")
      expect(
        p.chop_basename("/hey/howdy/there.txt")
      ).must_equal ["/hey/howdy/", "there.txt"]
      # peep inside Pathname class and see that we are memoizing as expected
      h = Pathname.send :class_variable_get, :@@memoized_chop_basename
      expect(
        Marshal.load(h[Array("/hey/howdy/there.txt")])
      ).must_equal ["/hey/howdy/", "there.txt"]
    end
  end

end


