# utility to return class of instance but class itself in case of class
# because class of a class is Class, not the class itself
# odd that Ruby itself lacks this
def classof(thing)
  [Class, Module].include?(thing.class) ? thing : thing.class
end

def myrequire(*what)
  # (1) no penalty for failure; we catch the LoadError and we don't re-raise
  # (2) arg can be an array, so multiple requires can be combined in one line
  # (3) array element itself can be a pair, in which case second must be array of desired includes as symbols
  # that way, we don't try to perform the includes unless the require succeeded
  # and we never *say* the include as a module, so it can't fail at compile time
  # and if an include fails, that does raise all the way since we don't catch NameError
  what.each do |thing|
    begin
      require((t = Array(thing))[0])
      Array(t[1]).each {|inc| classof(self).send(:include, self.class.const_get(inc)) rescue puts "Warning: failed to include #{inc.to_s}"}
    rescue LoadError
      puts "Warning: Require failed", "This could cause trouble later... or not. Here's the error message we got:"
      puts $!
    end
  end
end

# temp change to new kramdown, for testing purposes
# f = '/Users/mattleopard/Downloads/gettalong-kramdown-7e6e1d7/lib'
# $:.unshift f unless $:[0] == f

def myraise(what)
  raise RuntimeError, what, caller[0] # reduce callstack to line where "myraise" was called
end

module Memoizable # based on code by James Edward Gray
  def memoizeORIGINAL( name, cache = Hash.new )
    #return # testing, bypass
    original = "__unmemoized_#{name}__"
    ([Class, Module].include?(self.class) ? self : self.class).class_eval do
      alias_method original, name
      private      original
      define_method(name) { |*args| cache[args] ||= send(original, *args) }
    end
  end
  def memoize( name, cache = Hash.new )
    #return # switch off, testing / profiling
    # code expanded to be less elegant but more instrumentable
    original = "__unmemoized_#{name}__"
    class_variable_set("@@memoized_#{name}", cache) # helps debug, etc.
    classof(self).class_eval do
      alias_method original, name
      private original
      define_method(name) do |*args|
        # provide a bypass
        return send(original, *args) if @memoize == false
        unless cache.key?(args)
          # puts "memoizing #{name} for #{args}"
          temp = send(original, *args)
          cache[args] = Marshal.dump(temp)
          return temp # here's my current reasoning: 
          # we must not return a pointer to cache contents, lest it be changed
          # on the other hand, dump/load is time-consuming
          # so let's compromise: dump now, load later, thus skipping the dump step down the road
        else
          # puts "using memoized #{name} for #{args}"
          return Marshal.load(cache[args]) # return deep copy so we can't accidentally alter cache
        end
      end
    end
  end
end

class Hash # convenience methods
  def fetch2(k) # crummy name, but what the heck; utility to try string version of a symbol key
    # we use this restricted approach because in case of a tie the symbol must win
    # why? because directives from the page are symbols, and must take precedence
    raise "fetch2 argument #{k} must be a symbol" unless k.kind_of?(Symbol)
    self[k].nil? ? self[k.to_s] : self[k]
    # but why am I testing for nil when the hash might not return nil for non-existent keys?
    # could say this:
    # self.key?(k) ? self[k] : self[k.to_s]
    # however, that breaks BindingMaker (TODO: I have to figure out why)
  end
end

class LCHash < Hash # implement pseudo-case-insensitive fetching
  # if your key is lowercase (symbol or string), then incorrectly cased fetch requests will find it
  def [](k)
    k = k.downcase if !key?(k) and k.respond_to?(:downcase)
    super
  end
end

class Symbol # convenience methods
  def downcase
    self.to_s.downcase.to_sym
  end
end

class String # convenience methods
  def dropNonAlphas
    tr('^a-zA-Z0-9_', '')
  end
end

class Array # convenience methods
  def nextprev(obj = nil, &block)
    ix = index( block_given? ? find(&block) : obj )
    return [nil, nil] unless ix
    [ ix > 0 ? fetch(ix-1) : nil, fetch(ix+1, nil) ]
  end
  def crunch # remove "trailing duplicates" by == (unlike uniq), assumes we are sorted already
    return self if self.length == 0
    result = enum_for(:each_cons, 2).map {|x,y| x unless x == y}.compact 
    # result << (result.last == last ? nil : last) # ????? I can't figure out under what circumstances we'd want to append nil like this
    # or when result.last would equal last
    # so for now I'm just changing this directly
    result << last
  end
end

=begin code to get dimensions of JPEG image, no longer used but left here as useful historical info
# Ruby 1.9 broken the original code from http://snippets.dzone.com/posts/show/805
# I have fixed it here so that it works under Ruby 1.8.7 and under Ruby 1.9
class JPEG # used by Pathname#image_size
  attr_reader :width, :height, :bits
  def initialize(file)
    if file.kind_of? IO
      examine(file)
    else
      File.open(file, 'rb') { |io| examine(io) }
    end
  end
private
  def examine(io)
    if RUBY_VERSION >= "1.9"
      class << io
        def getc; super.bytes.first; end
        def readchar; super.bytes.first; end
      end
    end
    class << io
      def readint; (readchar << 8) + readchar; end
      def readframe; read(readint - 2); end
      def readsof; [readint, readchar, readint, readint, readchar]; end
      def next
        c = readchar while c != 0xFF
        c = readchar while c == 0xFF
        c
      end
    end
    raise 'malformed JPEG' unless io.getc == 0xFF && io.getc == 0xD8 # SOI
    while marker = io.next
      case marker
        when 0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF # SOF markers
          length, @bits, @height, @width, components = io.readsof
          raise 'malformed JPEG' unless length == 8 + components * 3
        # colons not allowed in 1.9, change to "then"
        when 0xD9, 0xDA then  break # EOI, SOS
        when 0xFE then        @comment = io.readframe # COM
        when 0xE1 then        io.readframe # APP1, contains EXIF tag
        else                  io.readframe # ignore frame
      end
    end
  end
end
=end

require 'pathname'
require 'uri'

class Pathname # convenience methods
  def to_str
    to_s # work around 1.9 withdrawal of to_str, which does implicit conversion
    # the problem is not so much my own code...
    # ...as that sites rely on the implicit behavior
  end
  def contains?(p)
    p.ascend {|dir| break true if self == dir } # nil otherwise
  end
  def simplename # name without extension
    self.basename(self.extname)
  end
  def needs_update_from(p) # compare mod dates
    !self.exist? || self.mtime < p.mtime
  end
  def relative_uri_from(p2) # derive relative (partial) URI
    # unfortunately a relative path is not the same as a relative uri, so can't use relative_path_from
    # so we construct a pair of pseudo http URLs and have URI do the work
    p1 = Pathname(self)
    
    raise "expecting absolute path" unless p1.absolute? && p2.absolute?
    
    # attempt to work around change in URI behavior in Ruby 1.9
    # if a real directory, guarantee trailing slash
    p1 = File.join(p1,"") if p1.directory?
    p2 = File.join(p2,"") if p2.directory?
    
    #uri1 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => self.to_s
    #uri2 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => p2.to_s
    
    uri1 = URI(URI.escape("file://" + p1.to_s))
    uri2 = URI(URI.escape("file://" + p2.to_s))
    return uri1.route_from(uri2).path
  end
=begin code to get size of various sorts of image
# no longer used; we now use the Dimensions gem, which provides a unified locus for all image types
  def image_size # read image file height and width
    # stolen from the Internet :) http://snippets.dzone.com/posts/show/805
    case self.extname.downcase
    when ".png"
      return self.read[0x10..0x18].unpack('NN')
    when ".gif"
      return self.read[6..10].unpack('vv') # SS didn't work OMM, byte order problem no doubt
    when ".jpg", ".jpeg"
      j = JPEG.new(self.to_s)
      return [j.width, j.height]
    when ".tif", ".tiff"
      t = EXIFR::TIFF.new(self.to_s)
      return [t.width, t.height]
    else
      return [nil, nil]
    end
  end
=end
  def image_size # read image file height and width
    # we now use Dimensions gem
    case self.extname.downcase
    when ".png", ".gif", ".jpg", ".jpeg", ".tif", ".tiff"
      return Dimensions::dimensions(self)
    else
      return [nil, nil]
    end
  end
=begin
  # also, memoize chop_basename because we seem to spend inordinate time there
  @@chopbasenamecache = Hash.new()
  alias :old_chop_basename :chop_basename
  def chop_basename(p)
    result = nil
    unless (result = @@chopbasenamecache[p])
      result = old_chop_basename(p)
      @@chopbasenamecache[p] = result
    end
    result
  end
=end
  extend Memoizable
  memoize :chop_basename
end


