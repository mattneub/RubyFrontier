
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
      Array(t[1]).each {|inc| include self.class.const_get(inc)}
    rescue LoadError
      puts "Failed to locate required \"#{thing}\"", "This could cause trouble later... or not. Here's the error message we got:"
      puts $!
    end
  end
end
myrequire "pathname", "yaml", "erb", "pp", "uri", "rubygems", "exifr", "enumerator"

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
    ([Class, Module].include?(self.class) ? self : self.class).class_eval do
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
    result = enum_for(:each_cons, 2).map {|x,y| x unless x == y}.compact 
    result << (result.last == last ? nil : last)
  end
end

class JPEG # used by Pathname#image_size, stolen from the Internet :) http://snippets.dzone.com/posts/show/805
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
    raise 'malformed JPEG' unless io.getc == 0xFF && io.getc == 0xD8 # SOI
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
    while marker = io.next
      case marker
        when 0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF # SOF markers
          length, @bits, @height, @width, components = io.readsof
          raise 'malformed JPEG' unless length == 8 + components * 3
        when 0xD9, 0xDA:  break # EOI, SOS
        when 0xFE:        @comment = io.readframe # COM
        when 0xE1:        io.readframe # APP1, contains EXIF tag
        else              io.readframe # ignore frame
      end
    end
  end
end

class Pathname # convenience methods
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
    raise "expecting absolute path" unless self.absolute? && p2.absolute?
    #uri1 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => self.to_s
    #uri2 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => p2.to_s
    uri1 = URI(URI.escape("file://" + self.to_s))
    uri2 = URI(URI.escape("file://" + p2.to_s))
    return uri1.route_from(uri2).path
  end
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

=begin make 'load' and 'require' include folder next to, and with same name as, this file 
that is where supplementary files go:
(1) stuff to keep this file from getting too big
(2) user.rb, where the user can maintain the UserLand::User class
uses our Pathname convenience method so we couldn't do this until now
=end
p = Pathname.new(__FILE__)
ljfolder = p.dirname + p.simplename
$: << ljfolder.to_s
$usertemplates = ljfolder + "user" + "templates"
$newsite = ljfolder + "newsite"

myrequire 'opml'

=begin environment in which macro evaluation and outline rendering takes place
  this is all done for maximum similarity to Frontier, and for sheer convenience
  user is guaranteed that current PageMaker instance's @adrPageTable is in scope
    thus user can say @adrPageTable[:fname] to get current page's fname
  user is allowed to say certain words in abbreviated form:
    * "html." can mean Html class (html.getLink) or current PageMaker instance (html.getPref)
      in latter ca*se, no need to supply default params, since this is the current instance
    * "myTool()" can be myTool.rb in a #tools folder, defining method myTool()
    * "imageref()" can be StandardMacros method
      separated into StandardMacros for namespace clarity...
      ...but in fact subsumed into the PageMaker instance, so again, no need to supply default params
    * "fname" can be @adrPageTable[:fname] or @adrPageTable["fname"]
      good for getting, but doesn't work for setting, as Ruby will just create the name as local variable
      and not highly recommended for getting either, since confusing to read, and @adrPageTable is readily available
      but's a Frontier legacy so I've left it in (and I d*o use it)
=end
class BindingMaker
  def html # if user's expression starts with "html", return object with method_missing to handle rest of expression
    # so we need to send back an object that will allow us to hear about the *next* word ("getLink" etc.)
    # its job is to choose between, and dispatch to, either the Html class or the PageMaker instance
    # to make the latter possible, we capture a ref to the PageMaker instance
    itsPageMaker = @thePageMaker
    Module.new do
      class << self; self; end.send(:define_method, :method_missing) do |s, *args|
        if UserLand::Html.respond_to? s
          return UserLand::Html.send(s, *args)
        else
          return itsPageMaker.send(s, *args)
        end
      end
    end
  end
  # handle shortcut / bareword expressions in macro evaluation
  def method_missing(s, *args)
    # if starts with html., we are not called, html method above handled it
    # test for user.html.macros not needed, since user can inject into UserLand::Html via user.rb
    # test for tools table not needed, they are part of this BindingMaker object already

    # try html.standardMacros; it is included into PageMaker
    return @thePageMaker.send(s, *args) if UserLand::Html::StandardMacros.method_defined?(s)
    
    # try adrPageTable; unlike Frontier, and wisely I think, we allow implicit get but no implicit set
    if 0 == args.length and result = @adrPageTable.fetch2(s)
      return result 
    end
    
    begin
      super
    rescue Exception => e
      raise e.exception("BindingMaker unable to evaluate '#{s}'")
    end
  end
  def getBinding(); return binding(); end
  def initialize(thePageMaker)
    @thePageMaker = thePageMaker # so we can access it later
    @adrPageTable = thePageMaker.adrPageTable # so macros can get at it
  end
  attr_reader :thePageMaker
end

# open modules we will be defining; think of this as an outline of our structure
module UserLand
end
module UserLand::Html
  # module's class methods will go here
  # class PageMaker will go here
end
module UserLand::Html::StandardMacros
  # PageMaker includes these too
end
module UserLand::User
end
module UserLand::Renderers
  # class SuperRenderer will go here
end

# load the real code

myrequire 'userland_renderers'

myrequire 'userland_class_methods'

myrequire 'userland_standard_macros'

myrequire 'userland_pagemaker'

# load user.rb last of all, so user can define SuperRenderer subclass and use "user.rb" for overrides of anything
# location of user.rb is outside the bundle and is defined in a global $userrb which the user must set

myrequire $userrb rescue puts "No $userrb specified, did not load a user file."

