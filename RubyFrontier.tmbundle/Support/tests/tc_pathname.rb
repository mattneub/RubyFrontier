require "test/unit"

require File.dirname(File.dirname(File.expand_path(__FILE__))) + '/bin/RubyFrontier/longestJourneyUtilities.rb'

myrequire 'rubygems', 'dimensions'

class TestPathname < Test::Unit::TestCase
  def test_contains
    p = Pathname.new("/a/b/c")
    p2 = Pathname.new("/a/b/c/d/e")
    assert_equal(true, p.contains?(p2))
    assert_equal(nil, p2.contains?(p))
  end
  def test_simplename
    p = Pathname.new("a/b/c.crud")
    assert_equal(Pathname("c"), p.simplename)
  end
  def test_needs_update_from
    require 'tmpdir'
    tmp = Dir.tmpdir
    f1 = tmp + "a.txt"
    File.open(f1, "w") {|io| io.puts "howdy"}
    f2 = tmp + "b.txt"
    begin
      File.delete(f2)
    rescue
    end
    sleep(2) # gotta sleep or the two mtime values will be identical
    assert_equal(true, Pathname(f2).needs_update_from(Pathname(f1)))
    assert_raises(Errno::ENOENT) { Pathname(f1).needs_update_from(Pathname(f2)) }
    File.open(f2, "w") {|io| io.puts "howdy"}
    assert_equal(true, Pathname(f1).exist?)
    assert_equal(true, Pathname(f2).exist?)
    assert_equal(false, Pathname(f2).needs_update_from(Pathname(f1)))
    assert_equal(true, Pathname(f1).needs_update_from(Pathname(f2)))
  end
  def test_relative_uri_from
    assert_raises RuntimeError do
      Pathname("test1").relative_uri_from(Pathname("test2"))
    end
    assert_raises RuntimeError do
      Pathname("/test1").relative_uri_from(Pathname("test2"))
    end
    assert_raises RuntimeError do
      Pathname("test1").relative_uri_from(Pathname("/test2"))
    end
    assert_equal("test2.txt", Pathname("/top/test2.txt").relative_uri_from(Pathname("/top/test1.txt")))
    assert_equal("../test2.txt", Pathname("/top/test2.txt").relative_uri_from(Pathname("/top/down/test1.txt")))
    assert_equal("../../test2.txt", Pathname("/top/test2.txt").relative_uri_from(Pathname("/top/down/down/test1.txt")))
    assert_equal("test2.txt", Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/down/test1.txt")))
    assert_equal("down/test2.txt", Pathname("/top/down/test2.txt").relative_uri_from(Pathname("/top/test1.txt")))
    assert_equal("down%20down/test2.txt", Pathname("/top/down down/test2.txt").relative_uri_from(Pathname("/top/test1.txt")))
    # issue exposed by change in URI behavior
    assert_equal("./", Pathname("/folder/").relative_uri_from(Pathname("/folder/firstpage.txt")))
    # the problem is that Pathname often gives us names like "/folder" without the final slash...
    # ... and then that fails on Ruby 1.9
    # however, I've got a workaround in cases where the path is real and can thus be tested with directory?
    assert_equal("./", Pathname("~").expand_path.relative_uri_from(Pathname("~/test1.txt").expand_path))
  end
  def test_image
    p = Pathname(__FILE__).dirname + "images"
    assert_equal([372,37], (p + "im.gif").image_size)
    assert_equal([372,37], (p + "im.jpg").image_size)
    assert_equal([372,37], (p + "im.png").image_size)
    assert_equal([372,37], (p + "im.tif").image_size)
    assert_equal([nil, nil], (p + "im.pct").image_size) # we don't do PICT
  end
  def test_memo
    p = Pathname("/hey/ho/howdy/there.txt")
    assert_equal(["/hey/howdy/", "there.txt"], p.chop_basename("/hey/howdy/there.txt"))
    # peep inside Pathname class and see that we are memoizing as expected
    h = Pathname.send :class_variable_get, :@@memoized_chop_basename
    assert_equal(["/hey/howdy/", "there.txt"], Marshal.load(h[Array("/hey/howdy/there.txt")]))
  end
end
