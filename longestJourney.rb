
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
      puts "Failed to locate required \"#{thing}\". This could cause trouble later... or not. Here's the error message we got:"
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

=begin superclass from which outline renderers are to inherit
this allows outline renderers to enjoy the same environment as macro evaluation (see on BindingMaker, above)
(this is not a Frontier feature, but it sure should be! makes life a lot easier;
e.g. you can reach @adrPageTable, tools, Html methods really easily)
so, an outline renderer must be a class deriving from UserLand::Renderers::SuperRenderer
subclasses should not override "initialize" without calling super or imitating
subclasses must implement "render(op)" where "op" is an Opml object (see opml.rb)
=end
module UserLand
end
module UserLand::User
end
module UserLand::Renderers
end
class UserLand::Renderers::SuperRenderer
  def initialize(thePageMaker, theBindingMaker)
    @thePageMaker = thePageMaker # so we can access it later
    @adrPageTable = thePageMaker.adrPageTable # so macros can get at it
    @theBindingMaker = theBindingMaker # to provide macro evaluation environment
  end
  def method_missing(s, *args)
    @theBindingMaker.send(s, *args) # delegation (fixes bug, previously I was sending straight to method_missing)
  end
  def render
    raise "Renderer failed to implement render()"
  end
end

# public interface for rendering a page (class methods)
# also general utilities without reference to any specific page being rendered
module UserLand::Html
  class << self; extend Memoizable; end # have to talk like this in order to memoize class/module methods
  def self.guaranteePageOfSite(adrObject)
    adrObject = Pathname(adrObject).expand_path
    myraise "No such file #{adrObject}" unless adrObject.exist?
    myraise "File #{adrObject} not a site page" unless self.everyPageOfSite(adrObject).include?(adrObject)
  end
  def self.releaseRenderedPage(adrObject, flPreview = true, doTimings = true)
    time = Time.new.to_f if doTimings # if you really want to, you can turn off the timings output
    
    adrObject = Pathname(adrObject).expand_path
    self.guaranteePageOfSite(adrObject) # raises if not
    
    # TODO: omitting "extra templates" logic
    
    # TODO: omitting file writer startup mechanism, adrStorage unused
    # in fact, callFileWriterStartup is now completely unused now that getFtpSiteFile has been extracted from it
    # adrStorage = callFileWriterStartup(adrObject)
          
    pm = PageMaker.new
    pm.buildObject(adrObject)
    puts "page built in #{Time.new.to_f - time} seconds" if doTimings
    pm.writeFile
    
    # TODO: omitting file writer shutdown mechanism
    # callFileWriterShutdown(adrObject, adrStorage)
    
    pm.saveOutAutoglossary # save out autoglossary if any
        
    if flPreview && (File.extname(pm.adrPageTable[:fname]) =~ /\.htm/i) # supposed to be a test for browser displayability
      if (apacheURL = pm.adrPageTable[:ftpsite][:apacheURL])
        f = pm.adrPageTable[:f].relative_path_from(Pathname(pm.adrPageTable[:ftpsite][:apacheSite]).expand_path)
        `open #{URI.escape(apacheURL + f)}`
      else
        `open file://#{URI.escape(pm.adrPageTable[:f].to_s)}`
      end
    end
    
  end
  def self.publishSite(adrObject, preflight=true)
    adrObject = Pathname(adrObject).expand_path
    self.guaranteePageOfSite(adrObject) # raises if not
    self.preflightSite(adrObject) if preflight
    self.everyPageOfSite(adrObject).each do |p|
      puts "publishing #{p}"
      self.releaseRenderedPage(p, (p == adrObject)) # the only one to open in browser is the one we started with
    end
  end
  def self.getFtpSiteFile(p)
    # walk upwards to the first folder containing an #ftpSite file, and return that file as a Pathname
    # if what you wanted was the folder itself, just get the file's dirname
    Pathname(p).dirname.ascend do |dir|
      dir.each_entry { |f| return dir + f if "#ftpsite" == f.simplename.to_s.downcase }
      myraise "Reached top level without finding #ftpsite; #{p} apparently not in a site source folder" if dir.root?
    end
  end
  def self.everyPageOfFolder(f)
    # a page is anything in the folder not starting with # or inside a folder starting with #
    # that doesn't mean every page is a renderable; it might merely be a copyable, but it is still a page
    # "in" means at any depth
    # distinguish from pagesInFolder which is shallow, only during rendering, only renderables, and uses #nextprevs order
    result = Array.new
    Pathname(f).find do |p|
      Find.prune if p.basename.to_s =~ /^[#.]/
      result << p if (!p.directory? && p.simplename != "") # ignore invisibles
    end
    result
  end
  class << self; memoize :everyPageOfFolder; end # have to talk this way yadda yadda
  def self.everyPageOfSite(adrObject)
    self.everyPageOfFolder(self.getFtpSiteFile(adrObject).dirname)
  end
  def self.preflightSite(adrObject)
    # prebuild autoglossary using every page of table containing adrObject path
    glossary = LCHash.new
    pm = nil # so that we have a PageMaker object left over at the end
    self.everyPageOfSite(Pathname(adrObject)).each do |p|
      pm = PageMaker.new
      pm.memoize = false # so if we then publishSite, existing values won't bite us
      pm.buildPageTableFully(p)
      tempGlossary = LCHash.new
      pm.addPageToGlossary(p, tempGlossary) # downcases for us
      glossary.merge!(tempGlossary) do |k, vold, vnew| # notify user of non-uniques
        puts "----", "Non-unique autoglossary entry detected for #{k}",
          vold.inspect, "vs.", vnew.inspect, "while processing #{p}" if vold != vnew
        vnew
      end
    end
    pm.saveOutAutoglossary(Hash[glossary]) # save out resulting autoglossary
  end  
=begin  
  def self.callFileWriterStartup(adrObject, adrStorage=Hash.new) # UNUSED
    # fill in adrStorage and return it
    ftpsite = getFtpSiteFile(adrObject)
    ftpsiteHash = YAML.load_file(ftpsite)
    adrStorage[:adrftpsite] = ftpsite
    adrStorage[:method] = ftpsiteHash[:method]
    adrStorage = LCHash[adrStorage] # convert to an LCHash so lowercase keys work
    return adrStorage
  end
=end
  def self.getLink(linetext, url, options={})
    # options (hash of symbol-string pairs) can be any <a> tag attributes
    # can also be :anchor, which is treated specially; we check for initial hash-character and append to url
    # can also be :othersite, used by our refglossary system before the url
    opt = options.map do |k,v|
      case k
      when :othersite; url = v + "^" + url; nil
      when :anchor; url = url + ("#" + v).squeeze("#"); nil
      else %{#{k.to_s}="#{v}"}
      end
    end.compact.join(" ")
    %{<a href="#{url}"#{" " + opt if !opt.empty?}>#{linetext}</a>}
  end
  def self.newSite()
    s = `#{ENV['TM_SUPPORT_PATH']}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog filesave --title "New Web Site" --text "Specify a folder to create"`
    exit if s == "" # user cancelled
    p = Pathname(s.chomp)
    p.mkpath
    FileUtils.cp_r($newsite.to_s + '/.', p)
    FileUtils.rm((p + "#autoglossary.yaml").to_s) # just causes errors if it's there
    # also get rid of svn leftovers if present
    `find '#{p}' -name ".svn" -print0 | xargs -0 rm -R -f`
    `"#{ENV['TM_SUPPORT_PATH']}/bin/mate" '#{p}'`
  end
  def self.traverseLink(adrObject, linktext)
    autoglossary = self.getFtpSiteFile(Pathname(adrObject)).dirname + "#autoglossary.yaml"
    if autoglossary.exist?
      entry = LCHash[(YAML.load_file(autoglossary.to_s))][linktext.downcase]
      if entry && entry[:adr] && entry[:adr].exist?
        return `"#{ENV['TM_SUPPORT_PATH']}/bin/mate" '#{entry[:adr]}'`
      end
    end
    puts "Not found." # appears in tooltip in TM
  end
end


# standard rendering utilities that macros can call without prefix
# they are separate so I can determine whether a call is to one of them...
# ...but then they are included in the PageMaker class for actual calling, so they can access the current page table
# (see BindingMaker for the routing mechanism here)
module UserLand::Html::StandardMacros
  GENERATOR = "RubyFrontier"
  def linkstylesheet(sheetName, adrPageTable=@adrPageTable) # link to one stylesheet
    # you really ought to use linkstylesheets instead, it calls this for you
    # TODO: Frontier's logic for finding the style sheet (source) is much more complex
    # I just assume we have a #stylesheets folder containing .css files
    # and I also just assume we'll write it into a folder called "stylesheets" at top level
    sheetLoc = adrPageTable[:siteRootFolder] + "stylesheets" + (sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".css")
    source = adrPageTable["stylesheets"] + "#{sheetName}.css"
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    # write out the stylesheet if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing css (#{sheetName})!"
      FileUtils.cp(source, sheetLoc, :preserve => true)
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    %{<link rel="stylesheet" href="#{pageToSheet}" type="text/css" />\n}
  end
  def linkjavascript(sheetName, adrPageTable=@adrPageTable) # link to one javascript
    # you really ought to use linkjavascripts instead, it calls this for you
    # TODO: as with linkstylesheet, my logic is very simplified:
    # I just assume we have a #javascripts folder and we write to top-level "javascripts"
    sheetLoc = adrPageTable[:siteRootFolder] + "javascripts" + (sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".js")
    source = adrPageTable["javascripts"] + "#{sheetName}.js"
    raise "javascript #{sheetName} does not seem to exist" unless source.exist?
    # write out the javascript if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing javascript (#{sheetName})!"
      FileUtils.cp(source, sheetLoc, :preserve => true)
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    %{<script src="#{pageToSheet}" type="text/javascript" ></script>\n}
  end
  def embedstylesheet(sheetName, adrPageTable=@adrPageTable) # embed stylesheet
    # you really ought to use linkstylesheets instead, it calls this for you
    # TODO: as with linkstylesheet, unlike Frontier, my logic for finding the stylesheet is very simplified
    # must be in #stylesheets folder as css file, end of story
    source = adrPageTable["stylesheets"] + "#{sheetName}.css"
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    %{\n<style type="text/css">\n<!--\n#{File.read(source)}\n-->\n</style>\n}
  end
  def linkstylesheets(adrPageTable=@adrPageTable) # link to all stylesheets requested in directives
    # call this, not linkstylesheet; it lets you link to multiple stylesheets
    # new way, we maintain a "linkstylesheets" array (see incorporateDirective()), because with CSS, order matters
    # another new feature: we now permit directive embedstylesheet
    s = ""
    Array(adrPageTable[:linkstylesheets]).each do |name|
      s << linkstylesheet(name, adrPageTable)
    end
    if sheet = adrPageTable.fetch2(:embedstylesheet)
      s << embedstylesheet(sheet)
    end
    s
  end
  def linkjavascripts(adrPageTable=@adrPageTable) # link to all javascripts requested in directives
    # not in Frontier at all, but clearly a mechanism like this is needed
    # works like "meta", allowing multiple javascriptXXX directives to ask that we link to XXX
    s = ""
    adrPageTable.keys.select do |k| # key should start with "javascript" but not *be* javascript (or the folder "javascripts")
      k.to_s =~ /^javascript./i && k.to_s.downcase != "javascripts"
    end.each { |k| s << linkjavascript(k.to_s[10..-1], adrPageTable) }
    s
  end
  def metatags(htmlstyle=false, adrPageTable=@adrPageTable) # generate meta tags
    htmlText = ""
    
    # charset, must be absolutely first
    if getPref("includemetacharset", adrPageTable)
      htmlText << %{\n<meta http-equiv="content-type" content="text/html; charset=#{getPref("charset", adrPageTable)}" />}
    end
    
    # generator
    if getPref("includemetagenerator", adrPageTable)
      htmlText << %{\n<meta name="generator" content="#{GENERATOR}" />}
    end
    
    # turn directives whose name starts with "meta" into meta tag
    # e.g. directive metacool, value "RubyFrontier", generates <meta name="cool" content="RubyFrontier">
    # directive metaequivcool, value "RubyFrontier", generates <meta http-equiv="cool" content="RubyFrontier">
    adrPageTable.select {|k,v| k.to_s =~ /^meta./i}.each do |k,v| # key should start with "meta" but not *be* "meta"
      type, metaName = ((k = k.to_s) =~ /^metaequiv/i ? ["http-equiv", k[9..-1]] : ["name", k[4..-1]])
      htmlText << %{\n<meta #{type}="#{metaName}" content="#{v}" />}
    end
    
    # opportunity to insert anything whatever into head section
    # TODO: revise so that more than one insertion is possible?
    htmlText << "\n" + adrPageTable[:meta] if adrPageTable[:meta]
    
    # allow for possibility that <meta /> syntax is illegal, as in html
    htmlText = htmlText.gsub("/>",">") if htmlstyle
    htmlText + "\n"
  end
  def pageheader(adrPageTable=@adrPageTable) # generate standard page header from html tag to body tag
    # if pageheader directive exists, assume macro was explicitly called in error
    # cool because template can contain pageheader() call with or without #pageheader directive elsewhere
    return "" if adrPageTable.fetch2(:pageheader)
    # our approach is simply to provide a standard header
    # note that we do not return it! we slot it into the #pageheader directive for later processing...
    # ... and just return an empty string
    adrPageTable[:pageheader] = '
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<%= metatags() %>
<%= linkstylesheets() %>
<%= linkjavascripts() %>
<title><%= title %></title>
</head>
<%= bodytag() %>
'
    return ""
  end
  def pagefooter(t="") # generate standard page footer, just closing body and html tags
    # t param is in case extra material needs to be inserted between the tags
    # for example, might want a comment to delimit things for dreamweaver or something
    return "</body>\n#{t}\n</html>\n"
  end
  def bodytag(adrPageTable=@adrPageTable) # generate body tag, drawing attributes from directives
    # really should not be using any of these attributes! that's what CSS is for; but hey, that's Frontier
    htmltext = ""
    
    if s = adrPageTable.fetch2(:background)
      htmltext << %{ background="#{getImageData(s, adrPageTable)[:url]}" } rescue ""
    end

    attslist = %w{bgcolor alink vlink link 
      text topmargin leftmargin marginheight 
      marginwidth onload onunload
    }
    attslist.each do |oneatt|
      if s = adrPageTable.fetch2(oneatt.to_sym)
        if %w{alink bgcolor text link vlink}.include?(oneatt)
          # colors should be hex and start with #
          unless s =~ /^#/
            if s.length == 6
              unless s =~ /[^0-9a-f]/i
                s = "#" + s
              end
            end
          end
        end
        htmltext << %{ #{oneatt}="#{s}"}
      end
    end 
    "<body#{htmltext}>"
  end
  def imageref(imagespec, options=Hash.new, adrPageTable=@adrPageTable) # create img tag
    # finding the image, copying it out, and obtaining its height and width and relative url, is the job of getImageData
    imageTable = getImageData(imagespec, adrPageTable)
    options = Hash.new if options.nil? # become someone might pass nil
    height = options[:height] || imageTable[:height]
    width = options[:width] || imageTable[:width]
    htmlText = %{<img src="#{imageTable[:url]}" }
    # added :nosize to allow suppression of width and height
    htmlText << %{width="#{width}" height="#{height}" } unless (!width && !height) || options[:nosize]
    %w{name id alt hspace vspace align style class title border}.each do |what|
      htmlText << %{ #{what}="#{options[what.to_sym]}" } if options[what.to_sym]
    end
    
    # some attributes get special treatment
    # usemap, must start with #
    if (usemap = options[:usemap])
      usemap = ("#" + usemap).squeeze("#")
      htmlText << %{ usemap="#{usemap}" }
    end
    if options[:ismap]
      htmlText << ' ismap="ismap" '
    end
    # lowsrc not supported (not valid HTML any more)!
    # rollsrc, simple rollover creation
    if (rollsrc = options[:rollsrc])
      htmlText << %{ onmouseout="this.src='#{imageTable[:url]}'" }
      htmlText << %{ onmouseover="this.src='#{getImageData(rollsrc, adrPageTable)[:url]}'" }
    end
    # explanation, we now use "alt"; anyhow, there *must* be one
    unless options[:alt]
      htmlText << %{ alt="image" }
    end
    htmlText << " />"
    # neaten
    htmlText = htmlText.squeeze(" ")
    # glossref, wrap whole thing in link ready for normal handling
    # unlikely (manual <a> or html.getLink is way better) but it's Frontier, someone might want to use it
    if (glossref = options[:glossref])
      htmlText = %{<a href="#{glossref}">#{htmlText}</a>}
    end
    htmlText
  end
end


# actual page renderer; maintains state, so it's a class, PageMaker
# includes standard macros so they can access its ivars
class UserLand::Html::PageMaker
  class Sandbox # class for reading a ruby file into (file's methods become methods of this object)
    def initialize(adrObject)
      instance_eval(File.read(adrObject))
    end
  end
  include UserLand::Html::StandardMacros
  extend Memoizable
  attr_reader :adrPageTable
  attr_accessor :memoize
  def initialize(adrPageTable = LCHash.new)
    @adrPageTable = adrPageTable
    @memoize = true # default; instantiator can always turn it off
  end
  def renderable?(adrObject)
    # no error-checking; purely a matter of suffix
    [".txt", ".opml", ".rb"].include?(Pathname(adrObject).extname)
  end
  def writeFile(adrStorage=nil, s=@adrPageTable[:renderedtext], adrPageTable=@adrPageTable)
    # TODO: eventually we might support ftp like Frontier, but right now we just write to disk
    # so the adrStorage parameter isn't being used for anything yet
    # the usual thing is to call with no parameters (see releaseRenderedPage):
    # we write out the page we have rendered, page table tells us how
    f = adrPageTable[:f] # target file
    raise "attempt to write into site table" if adrPageTable[:adrSiteRootTable].contains?(f)
    f.dirname.mkpath
    if renderable?(adrPageTable[:adrObject])
      File.open(f,"w") do |io|
        io.write s
      end
      puts "Rendered #{adrPageTable[:adrObject]}"
    else # just copy it
      if f.needs_update_from(adrPageTable[:adrObject])
        FileUtils.cp(adrPageTable[:adrObject], f, :preserve => true)
        puts "Copied #{adrPageTable[:adrObject]}"
      end
    end
  end
  def callFilter(filter_name, adrPageTable=@adrPageTable)
    if adrPageTable["filters"]
      adrFilter = adrPageTable["filters"] + "#{filter_name}.rb"
      if adrFilter.exist?
        s = Sandbox.new(adrFilter)
        m = s.method(filter_name) rescue myraise("Filter file #{filter_name}.rb must define method #{filter_name}")
        case m.arity
        when 1
          s.send(filter_name, adrPageTable)
        when 2
          s.send(filter_name, adrPageTable, self)
        else
          myraise "Filter method #{filter_name} must take 1 or 2 parameters"
        end
      end
    end
  end
  def buildObject(adrObject, adrPageTable=@adrPageTable)
    # construct entire page table
    buildPageTableFully(adrObject)
    # if this is not a renderable, that's all
    return "" unless renderable?(adrObject)
    
    # if we've reached this point we're going to need a BindingMaker object
    # it provides an environment in which to deal with outline renderers and macro processing
    # load all tools into BindingMaker instance as sandbox
    # all method defs in tools become methods of BindingMaker
    # all outline renderers in tools spring into life as classes
    theBindingMaker = BindingMaker.new(self)
    begin
      v = nil # trick so that "v" is global to the block, in case "rescue" is called
      adrPageTable["tools"].each_value { |v| theBindingMaker.instance_eval(File.read(v)) }
    rescue SyntaxError
      raise "Trouble parsing #{v}"
    end
  
    # if the page is an outline or script, now render it (unlike Frontier which did it earlier, unnecessarily)
    case adrPageTable[:bodytext]
    when Opml # outline!
      # renderer is a subclass of module UserLand::Renderers::SuperRenderer
      # can be defined in user.rb, or as an .rb file in tools 
      # it should not override initialize in such a way as to disable it, and must accept render with 1 arg (an Opml object)
      # has access to @thePageMaker and @adrPageTable
      myraise("Failed to specify an outline renderer (renderOutlineWith)!") unless renderer = adrPageTable[:renderoutlinewith]
      begin
        renderer_klass = UserLand::Renderers.module_eval(renderer) 
      rescue
        myraise "Renderer #{renderer} not found!"
      end
      adrPageTable[:bodytext] = renderer_klass.new(self, theBindingMaker).render(adrPageTable[:bodytext])
    when Sandbox # script!
      # must have a render() method, we call it in a sandbox, handing it the whole PageMaker object
      # after that, dude, you're on your own!
      renderer = adrPageTable[:bodytext]
      begin
        raise("") unless renderer.method(:render).arity == 1
      rescue
        myraise("Page object script must define render method accepting one parameter")
      end
      adrPageTable[:bodytext] = renderer.render(self)
    end
    
    # update autoglossary
    # in Frontier, pagefilter includes html.addPageToGlossary
    # but since you'd effectively never *not* want to do this, why force every site to have this pagefilter?
    # so I just call it explicitly
    addPageToGlossary(adrObject)
    
    # snippet support
    # this is not a Frontier feature, and in fact Frontier suffered from the lack of it
    # the idea is that you might want to do text substitution (like Frontier's glossary) *early*,
    # so that the text is processed like everything else
    # a snippet is a .txt file in a #tools folder, and has been loaded into a "snippets" hash
    # you can have direct access to it, obviously, via adrPageTable...
    # ...but here, as a shortcut, we substitute directly into [[...]]
    adrPageTable[:bodytext].gsub!(/\[\[(.*?)\]\]/) do
      if adrPageTable["snippets"] && adrPageTable["snippets"][$1]
        adrPageTable["snippets"][$1]
      else
        puts "Ignoring snippet substitution for #{$&}"
        $&
      end
    end
          
    # pagefilter, handed adrPageTable, expected to access :bodytext
    callFilter("pageFilter")
    
    # early exit option; provided because...
    # ...it may be, as in the case of a blog, where bodytext from many pages is embedded in a single page...
    # ...that there is no reason to go on, since we are only rendering to get the :bodytext
    return if adrPageTable[:stopAfterPageFilter]

    #template
    # if named, it will be a string; if found or "indirect", it will be a Pathname
    raise "No template found or specified" unless (adrTemplate = adrPageTable.fetch2(:template))
    if adrTemplate.kind_of?(String) # named template, look for it and convert to Pathname
      catch (:done) do
        [adrPageTable["templates"], $usertemplates].each do |f|
          if f && f.exist?
            f.children.each do |p|
              if p.simplename.to_s == adrTemplate
                adrTemplate = p
                throw :done
              end
            end
          end
        end
      end
      raise "Template #{adrTemplate} named but not found" unless adrTemplate.kind_of?(Pathname)
    end
    
    # run directives in the template
    s = runDirectives(adrTemplate)
    # TODO: omitting stuff about revising if #fileExtension was changed by template
      
    # if we have no title by now, that's an error
    raise "You forgot to give this page a title!" unless adrPageTable[:title]
    
    # embed page into template at <bodytext>
    # I've cut Frontier's <title> substitution feature, it saves nothing and leads to error
    # important to write it as follows or we get possibly unwanted \\, \1 substitution
    s = s.sub(/<bodytext>/i) {|x| adrPageTable[:bodytext]}
      
    # macros (except in pageheader, we haven't gotten there yet)
    s = processMacros(s, theBindingMaker.getBinding) unless !getPref("processmacros")
    
    # glossary expansion (resolve local <a> tags)
    s = resolveLinks(s)
      
    # pageHeader attribute or result of pageheader() standardmacro call instead
    # we don't handle this until now, because other stuff might need to influence title or bgcolor or something
    # might be named (symbol key) or found (string key); might be direct string or indirect pathname
    if ph = adrPageTable.fetch2(:pageheader)
      ph = File.read(ph) if ph.kind_of?(Pathname)
      s = processMacros(ph, theBindingMaker.getBinding) + s
    end
  
    # linefeed thing, not implemented
    # fatpages, not implemented
  
    adrPageTable[:renderedtext] = s
    
    # finalfilter, handed adrPageTable, expected to access :renderedtext
    callFilter("finalFilter")
  
  end
  def buildPageTableFully(adrObject, adrPageTable=@adrPageTable)
    # this has no exact Frontier analog; it's the first few lines of buildObject, factored out
    # the point is that Frontier's buildPageTable does not really finish building the page table...
    # ...but we need a routine that *does* fully finish (without rendering), so we can pull out directives properly
    # idea is to be lightweight but complete, so that resulting adrPageTable can be used for other purposes
  
    # walk hierarchy collecting directives
    buildPageTable(adrObject)
      
    # firstfilter
    callFilter("firstFilter")
  
    # obtain directives from within page object
    # insert page object, in some form, into page table
    adrPageTable[:bodytext] = tenderRender(adrPageTable[:adrobject])
    
    # work out paths and names:
    # :fname => name of file we will write out
    if renderable?(adrPageTable[:adrobject])
      adrPageTable[:fname] = getFileName(adrPageTable[:adrobject].simplename)
    else
      adrPageTable[:fname] = adrPageTable[:adrobject].basename
    end
    # :siteRootFolder => folder into which all pages will be written
    folder = getSiteFolder() # sets adrPageTable[:siteRootFolder] and returns it
    # :subDirectoryPath => relative path from :siteRootFolder to :f, or from :adrSiteRootTable to :adrObject
    # :adrSiteRootTable => folder containing #ftpsite marker, in which whole site object lives
    # (already set, in buildPageTableForDirectory)
    relpath = (adrPageTable[:adrobject].relative_path_from(adrPageTable[:adrSiteRootTable])).dirname
    adrPageTable[:subdirectorypath] = relpath
    # :f => full pathname of file we will write out
    adrPageTable[:f] = folder + relpath + adrPageTable[:fname]
    
    # insert user glossary
    if UserLand::User.respond_to?(:glossary)
      g = adrPageTable["glossary"]
      UserLand::User.glossary().each do |k,v|
        g[k.downcase] = v unless g[k]
      end
    end
  end
  def buildPageTable(adrObject, adrPageTable=@adrPageTable)
    # isolate this directory as parameter so we can memoize
    adrPageTable.merge!(buildPageTableForDirectory(adrObject.dirname))
    # record what object is being rendered
    adrPageTable[:adrobject] = adrObject
  end
  def buildPageTableForDirectory(adrObjectDir) # never call this directly unless you are buildPageTable!
    adrPageTable = Hash.new # *this* adrPageTable is purely local, its only purpose is to be handed back to buildPageTable
    # init hashes to gather stuff into as we walk up the hierarchy
    adrPageTable["tools"] = LCHash.new
    adrPageTable["glossary"] = LCHash.new
    adrPageTable["snippets"] = LCHash.new
    adrPageTable["images"] = LCHash.new
    adrPageTable[:linkstylesheets] = Array.new
  
    # walk file hierarchy looking for things that start with "#"
    # add things only if they don't already exist; that way, closest has precedence
    # if it is #prefs or #glossary, load as a yaml hash and merge with existing hash
    # if it is #ftpsite, determine root etc.
    # else, just hash pathname under simple filename
    catch (:done) do
      found_ftpsite = false
      adrObjectDir.ascend do |dir|
        dir.each_entry do |f|
          if /^#/ =~ f
            dirf = dir + f
            case f.simplename.to_s.downcase # special casing of certain directives
            when "#tools"
              # gather tools into tools hash, hashing pathnames under simple filenames
              # new feature (non-Frontier), .txt files go into snippets hash
              dirf.each_entry do |ff|
                unless /^\./ =~ (tool_simplename = ff.simplename.to_s.downcase)
                  case ff.extname
                  when ".rb"
                    adrPageTable["tools"][tool_simplename] ||= dirf + ff
                  when ".txt"
                    adrPageTable["snippets"][tool_simplename] ||= File.read(dirf + ff)
                  end
                end
              end
            when "#images" # gather images into images hash, hashing pathnames under simple filenames
              dirf.each_entry do |ff|
                unless /^\./ =~ (im_simplename = ff.simplename.to_s.downcase)
                  adrPageTable["images"][im_simplename] ||= dirf + ff
                end
              end
            when "#prefs" # flatten prefs out to become top-level entries of adrPageTable
              # we do NOT downcase this key; arbitrary directives can have meaningful case (as in #metaAppleTitle)
              YAML.load_file(dirf).each {|k,v| incorporateDirective(k, v, true, adrPageTable)}
            when "#glossary" # gather user glossary entries into glossary hash
              g = adrPageTable["glossary"]
              YAML.load_file(dirf).each do |k,v|
                g[k.downcase] = v unless g[k]
              end
            when "#ftpsite"
              found_ftpsite = true
              adrPageTable[:ftpsite] ||= YAML.load_file(dirf)
              adrPageTable[:adrsiteroottable] ||= dir
            else
              adrPageTable[f.simplename.to_s.downcase[1..-1]] ||= dirf # pathname hashed under simple filename
            end
          end
        end
        throw :done if found_ftpsite
      end
    end
    # if we found an autoglossary, yaml-load it into :autoglossary
    # (nothing like this in Frontier, we need this for our own autoglossary mechanism)
    adrGlossTable = adrPageTable["autoglossary"]
    adrPageTable[:autoglossary] = if adrGlossTable && adrGlossTable.exist?
      YAML.load_file(adrGlossTable)
    else
      Hash.new
    end
    # url-setting and some other stuff (fname, f) not yet done
    # there is an inefficiency in Frontier here: this is all done again after tenderRender
    # so I'm just omitting it here for now
    return adrPageTable
  end
  memoize :buildPageTableForDirectory
  def tenderRender(adrObject, adrPageTable=@adrPageTable)
    # sorry about the name of this method, but this is what Frontier calls it...
    # extract directives from page object and return suitable bodytext value
    # further disposal is based on class
    case File.extname(adrObject)
    when ".txt"
      return runDirectives(adrObject) # String
    when ".opml"
      return runOutlineDirectives(adrObject) # Opml
    when ".rb"
      s = Sandbox.new(adrObject) # Sandbox
      s.runDirectives(self) if s.respond_to?(:runDirectives)
      s
    else
      return "" # not a renderable, unimportant
    end
  end
  def runDirectives(adrObject, adrPageTable=@adrPageTable)
    # extract directives from start of text, return rest of text
    File.open(adrObject) do |io|
      while line = io.gets and line[0,1] == "#"
        runDirective(line[1..-1], adrPageTable)
      end
      line + (io.gets(nil) || "") # read all the rest
    end
  end
  def runOutlineDirectives(adrObject, adrPageTable=@adrPageTable)
    # extract directives from start of outline, return rest of outline
    op = Opml.new(adrObject.to_s)
    while aline = op.getLineText and aline[0,1] == "#"
      runDirective(aline[1..-1], adrPageTable)
      op.deleteLine
    end
    return op
  end
  def runDirective(linetext, adrPageTable=@adrPageTable)
    k,v = linetext.chomp.split(" ",2)
    # directive becomes symbol, not downcased (case can have meaning), overrides existing; value is evaled
    incorporateDirective(k.to_sym, eval(v, binding), false, adrPageTable) # "binding" for better error reports
  rescue SyntaxError
    raise "Syntax error: Failed to evaluate directive #{v}"
  end
  def incorporateDirective(k, v, yieldToExisting=false, adrPageTable=@adrPageTable)
    # bottleneck routine: give me a k (symbol or string) and a v (value) and I'll add it to the page table
    # the problem is that not all directives are created equal; in MOST cases adrPageTable[k] = v,
    # but it turns out to be useful to be able to special-case certain directives
    # yieldToExisting lets us use this both during page table build (true) and within a page (false)
    s = k.to_s
    # special-case stylesheet link directives; reason: stylesheet links have a meaningful order
    # we accept two forms of directive: stylesheetNormal true (old style) and linkstylesheets ["one", "two"] (new style)
    # there is NO OVERRIDE: stylesheet names are appended to :linkstylesheets array in order encountered,
    # and that is the order in which linkstysheets() macro will insert the links
    if s =~ /^stylesheet./i
      adrPageTable[:linkstylesheets] << s[10..-1]
    elsif s.downcase == "linkstylesheets"
      adrPageTable[:linkstylesheets] += v.to_a
    elsif s.downcase == "linkstylesheetsnot"
      adrPageTable[:linkstylesheets] -= v.to_a
    else
      if yieldToExisting
        adrPageTable[k] ||= v
      else
        adrPageTable[k] = v
      end
    end
  end
  def getFileName(n, adrPageTable=@adrPageTable)
    normalizeName(n) + getPref("fileextension", adrPageTable)
  end
  def normalizeName(n, adrPageTable=@adrPageTable)
    n = n.to_s
    n = n.dropNonAlphas if getPref("dropnonalphas", adrPageTable)
    n = n.downcase if getPref("lowercasefilenames", adrPageTable)
    n[0, getPref("maxfilenamelength", adrPageTable) - getPref("fileextension", adrPageTable).length]
  end
  def getSiteFolder(adrPageTable=@adrPageTable)
    # where shall we render/copy pages into? set :siteRootFolder, and return it as well
    return adrPageTable[:siteRootFolder] if adrPageTable[:siteRootFolder]
    folder = Pathname(adrPageTable[:ftpsite][:folder]).expand_path
    # ensure whole containing path exists; if not, use temp folder
    folder = Pathname(`mktemp -d /tmp/website.XXXXXX`) unless folder.dirname.exist?
    return (adrPageTable[:siterootfolder] = folder) # set in adrPageTable and also return it
  end
  def addPageToGlossary(adrObject, glossary=adrPageTable[:autoglossary], adrPageTable=@adrPageTable)
    # this is different from what Frontier does!
    # we maintain an #autoglossary on disk, loaded as :autoglossary hash
    # we do not save out; that is the job of whoever calls us to do that eventually
    # unlike Frontier, we make *two* entries (pointing to same object) keyed by title and by simple filename
    # thus, either of these is a legal "id" for refGlossary lookup
    # we also calculate url if there is a base url in #ftpsite
    h = Hash.new
    h[:path] = adrPageTable[:subDirectoryPath] + adrPageTable[:fname]
    h[:adr] = adrObject
    # linetext is title; might be nil, e.g. this might be a non-renderable (see preflightSite)
    if (linetext = adrPageTable[:title])
      # issue warning if page object has changed location
      changed = glossary[linetext] && (glossary[linetext][:adr] != adrObject)
      puts "#{adrObject} changed position from #{glossary[linetext][:adr]}" if changed
      h[:linetext] = linetext
    end
    # url in ftpsite might not exist
    begin
      url = adrPageTable[:ftpsite][:url].chomp("/") + "/" # ensure ends with slash
      h[:url] = URI::join(url, URI::escape(h[:path].to_s)).to_s
    rescue
    end
    # put into autoglossary hash, possibly twice
    # we downcase and use LCHash for lookup, but autoglossary itself is normal hash
    glossary[adrPageTable[:f].simplename.to_s.downcase] = h
    glossary[linetext.downcase] = h if linetext
  end
  def processMacros(s, theBinding, adrPageTable=@adrPageTable)
    # process macros
    # the Ruby equivalent of processing macros is to use ERB, so we do
    # reference munging like Frontier's is done in the BindingMaker class
    ERB.new(s).result(theBinding)
  rescue Exception => e # real nice error reporting
    line = e.backtrace.grep(/^\(erb\)/)[0].split(':')[1].to_i
    puts "Exception while evaluating line #{line}:"
    puts s.split("\n")[line-1]
    e.backtrace.grep(/^\(eval\)/).reverse.each {|b| arr = b.split(":"); puts "#{arr[2]}, line #{arr[1]}"}
    e.set_backtrace caller(0)
    raise
  end
  def resolveLinks(s, adrPageTable=@adrPageTable)
    # glossary expansion; my equivalent is to look for already existing <a href...> tags
    # ...generated no matter how, e.g. manually, with getLink, with markdown [](), whatever
    # we can resolve identifiers in user glossary or our autoglossary (see refGlossary)
    s.gsub /<a href="(.*?)"(.*?)>/i do |ref| 
      # NB href must come absolutely first, we are deliberately hard-coded on this format
      # this is cool because it means you can except an <a> tag from resolution merely by using a different format
      retval = ref # if nothing else, just return what we came in with
      href = $1
      rest = $2
      # to count as a candidate, must be clearly "local":
      # if contains dot or colon-slash-slash, or starts with #, assume this is a real URL, don't touch
      # but user can override the first two checks by escaping (double-backslash), thus saying, yes, do process me
      unless href =~ /[^\\]\./ || href =~ %r{[^\\]\://} || href =~ /^#/
        if href =~ /([^\\])\^/ # remote-site semantics, site^id (escape to prevent this interpretation)
          # site is relative filepath in glossary, id is to be looked up in autoglossary of that site
          begin
            id = $'
            path = refGlossary($` + $1)
            path = (adrPageTable[:adrSiteRootTable] + Pathname.new(path)).cleanpath + "#autoglossary.yaml"
            url = LCHash[YAML.load_file(path)][id.gsub('\\','')][:url]
            #TODO: failing to notice/barf if there is no url entry in the hash?
          rescue
            puts "Remote glossary lookup failed on #{href}, apparently while processing #{adrPageTable[:adrObject]}"
          end
        else # non-remote-site (normal) semantics
          url = refGlossary(href.gsub('\\',''))
          puts "RefGlossary failed on #{href}, apparently while processing #{adrPageTable[:adrObject]}" unless url
        end
        retval = url || "errorRefGlossaryFailedHere"
        retval = %{<a href="#{retval}"#{rest}>} # form link, restoring stuff after href tag if any
      end
      retval
    end
  end
  def refGlossary(name, adrPageTable=@adrPageTable)
    # return href referring to the named target from where we are, or nil
    # [NB possible breakage warning: used to return complete <a> tag - OTOH users should not be calling directly anyway]
    # Frontier merely substitutes a glossPath at this stage, but I don't see the need for that
    # as usual I am leaving out a certain amount of Frontier's logic here
    # also I'm departing from Frontier's logic: we have two hashes to look in:
    # "glossary" is user glossary of name-substitution pairs
    # :autoglossary is our glossary of hashes pointing to pages we have built
    # new (non-Frontier) logic: if name contains #, split into name and anchor, search, reassemble
    name, anchor = name.split("#", 2)
    anchor = anchor ? "#" + anchor : ""
    # autoglossary
    g = LCHash[adrPageTable[:autoglossary]]
    if g && g[name] && g[name][:path]
      path = adrPageTable[:siteRootFolder] + g[name][:path]
      return path.relative_uri_from(adrPageTable[:f]) + anchor
    end
    # user glossary
    g = adrPageTable["glossary"]
    if g && g[name]
      return g[name] + anchor
    end
    # failure
    nil
  end
  def getOneDirective(directiveName, adrObject, adrPageTable=@adrPageTable)
    # simple-mindedly pull a directive out of a page's contents
    # we now accept an array of directives, and if so, we return an array
    # we also accept a refglossary id instead of an absolute adrObject pathname
    adrObject = adrPageTable[:autoglossary][adrObject][:adr] unless adrObject === Pathname
    is_arr = directiveName.kind_of?(Array)
    directiveName = Array(directiveName)
    d = Hash.new
    case adrObject.extname
    when ".txt"
      runDirectives(adrObject, d)
    when ".opml"
      runOutlineDirectives(adrObject, d)
    end
    arr = directiveName.map {|name| d[name]}
    return arr if is_arr
    return arr[0] # if a scalar was supplied
  end
  def getTitleAndPath(id, adrPageTable=@adrPageTable)
    # grab title (linetext) and path from autoglossary; useful for macros
    return [nil,nil] unless adrPageTable[:autoglossary] && adrPageTable[:autoglossary][id]
    return adrPageTable[:autoglossary][id][:linetext], adrPageTable[:autoglossary][id][:path]
  end
  def getNextPrev(obj, adrPageTable=@adrPageTable)
    # useful for macros
    # return array of two identifiers, namely the prev and next renderable page at this level
    pagesInFolder(obj.dirname).nextprev(obj.simplename.to_s)
  end
  def pagesInFolder(folder, adrPageTable=@adrPageTable)
    # utility, also useful to macros
    # return array of identifiers of renderables in folder
    # suitable for use in autoglossary consultation (refGlossary and whatever calls it)
    # if there is a #nextprevs, the array is ordered as in the nextprevs
    # otherwise we just use alphabetical order (filesystem)
    # return nil if no result
    # memoized, since #nextprevs and folder contents unlikely to change during a rendering
    arr = Array.new
    nextprevs = folder + "#nextprevs.txt"
    if (nextprevs.exist?)
      arr = File.readlines(nextprevs).map {|line| line.chomp}
    else
      # if not, just use alphabetical order
      folder.children.each do |p|
        next if p.basename.to_s =~ /^[#.]/
        arr << p.simplename.to_s if renderable?(p)
      end
    end
    return (arr.length > 0 ? arr : nil)
  end
  memoize :pagesInFolder
  def getImageData(imageSpec, adrPageTable=@adrPageTable)
    # find image, get relative path, write out the image, get height and width
    # TODO: Frontier has fu for seeking the image, but I assume a single "images" hash gathered as we build page table
    raise "No 'images' folder found" unless adrPageTable["images"]
    imagePath = adrPageTable["images"][imageSpec]
    raise "Image #{imageSpec} not found" unless imagePath
    # TODO: I also assume single folder at top level (but I leave folder name as a pref)
    imagesFolder = adrPageTable[:siteRootFolder] + getPref("imagefoldername", adrPageTable)
    # actually write the image; I've always thought this is an inappropriate place to do this...
    # ... and would eventually like to change it (TODO)
    imagesFolder.mkpath
    imageTarg = imagesFolder + imagePath.basename
    FileUtils.cp(imagePath, imageTarg, :preserve => true) if imageTarg.needs_update_from(imagePath)
    # determine image dimensions, see Pathname mods
    width, height = imageTarg.image_size
    # construct and return image data table
    url = imageTarg.relative_uri_from(adrPageTable[:f])
    return {:width => width, :height => height, :path => imageTarg, :adrImage => imagePath, :url => url}
  end
  def getPref(s, adrPageTable=@adrPageTable)
    # look for pref value
    # first try page table; must write like this, we specifically want the nil test since false is a different case
    if !(result = adrPageTable[s]).nil? || !(result = adrPageTable[s.to_s]).nil? || !(result = adrPageTable[s.to_sym]).nil?
      result = true if result == "yes"
      result = false if result == "no"
      return result
    end
    # TODO: should try to get it from user.html.prefs but that doesn't exist yet
    # return built-in defaults
    case s.to_s.downcase
    when "fileextension"
      ".html"
    when "maxfilenamelength"
      31
    when "defaulttemplate"
      "normal"
    when "defaultfilename"
      "default"
    when "charset"
      "utf-8"
    when "imagefoldername"
      "images"
    else
      true
    end
  end
  def saveOutAutoglossary(g=nil, adrPageTable=@adrPageTable)
    g ||= adrPageTable[:autoglossary]
    if g
      f = adrPageTable[:adrSiteRootTable] + "#autoglossary.yaml"
      File.open(f, "w") { |io| YAML.dump(g, io) }
    end
  end
end

myrequire 'user' # last of all, so user can define SuperRenderer subclass and use "user.rb" for overrides of anything

