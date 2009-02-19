
def myrequire(*what)
  # (1) no penalty for failure; we catch the LoadError and we don't re-raise
  # (2) arg can be an array, so multiple requires can be combined in one line
  # (3) array element itself can be a pair, in which case second must be array of desired includes as symbols
  # that way, we don't try to perform the includes unless the require succeeded
  # and we never *say* the include as a module, so it can't fail at compile time
  # and if an include fails, that does raise all the way since we don't catch NameError
  what.each do |thing|
    begin
      if thing.kind_of?(Array)
        require thing[0]
        Array(thing[1]).each {|inc| include self.class.const_get(inc)}
      else
        require thing
      end
    rescue LoadError
      puts "Failed to located required \"#{thing}\". This could cause trouble later... or not. Here's the error message we got:"
      puts $!
    end
  end
end
myrequire "pathname", "yaml", "erb", "pp", "uri", "rubygems", "exifr", "enumerator"

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

class LCHash < Hash # implement pseudo-case-insensitive fetching
  # if your key is lowercase (symbol or string), then incorrectly cased fetch requests will find it
  alias :"old_fetch" :"[]"
  def [](k)
    return old_fetch(k) if key?(k)
    return old_fetch(k) unless [Symbol, String].include?(k.class)
    old_fetch(k.downcase)
  end
end

class Symbol # convenience methods
  def downcase
    self.to_s.downcase.to_sym
  end
end

class String # convenience methods
  def dropNonAlphas
    return self.gsub(/[^a-zA-Z0-9_]/, "")
  end
end

class Array # convenience methods
  def nextprev(obj = nil, &block)
    ix = (block_given? ? index(find(&block)) : index(obj))
    [ ix > 0 ? fetch(ix-1) : nil, ix < length - 1 ? fetch(ix+1) : nil ]
  end
  def crunch # remove "trailing duplicates" by ==, assumes we are sorted already
    result = []
    each_cons(2) {|x,y| result << x unless x == y}
    result << last unless result.last == last
    result
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
    return true unless self.exist?
    return true if self.mtime < p.mtime
    return false
  end
  def relative_uri_from(p2) # derive relative (partial) URI
    # unfortunately a relative path is not the same as a relative uri, so can't use relative_path_from
    # so we construct a pair of pseudo http URLs and have URI do the work
    # nice feature is that build2 also escapes as needed
    raise "expecting absolute path" unless self.absolute? && p2.absolute?
    uri1 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => self.to_s
    uri2 = URI::HTTP.build2 :scheme => "http", :host => "crap", :path => p2.to_s
    return uri1.route_from(uri2)
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
$: << (p.dirname + p.simplename).to_s
$usertemplates = (p.dirname + p.simplename) + "user" + "templates"
$newsite = (p.dirname + p.simplename) + "newsite"

myrequire 'opml'

=begin special dispatcher needed by BindingMaker
here's the deal: if the user says e.g. html.getLink, BindingMaker's method_missing gets "html"
that is not enough for us to know whether to route to the Html *class* or the PageMaker *instance*
so we need to send back an answer that will allow us to hear about the *next* word ("getLink")
so BindingMaker sends back its HtmlDispatcher
thus, HtmlDispatcher's method_missing is guaranteed to be called only for a word introduced by "html."
its job is to choose between, and dispatch to, either the Html class or the PageMaker instance
to make the latter possible, it is created with a ref to the BindingMaker instance, which has a ref to the PageMaker instance
=end
class HtmlDispatcher
  def method_missing(s, *args)
    if UserLand::Html.respond_to? s
      return UserLand::Html.send(s, *args)
    else
      return @theBindingMaker.thePageMaker.send(s, *args)
    end
  end
  def initialize(caller)
    @theBindingMaker = caller
  end
end

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
  # handle shortcut / bareword expressions in macro evaluation
  def method_missing(s, *args)
    # if user's expression begins with explicit "html.", it is calling a built-in utility
    return @theHtmlDispatcher if s == :html
    
    # test for user.html.macros - not needed! 
    # if the user wants to inject something into UserLand::HTML via user.rb, that's fine
    
    # try tools table
    # we have loaded tools method defs into this BindingMaker object already
    # if they are not seen automatically (in which case method_missing was never even called), we expose them like this
    return self.send(s, *args) if self.respond_to?(s)

    # try html.standardMacros
    return @thePageMaker.send(s, *args) if UserLand::Html::StandardMacros.method_defined?(s)
    
    # try adrPageTable; unlike Frontier, and wisely I think, we allow implicit get but no implicit set
    if 0 == args.length and result = (@adrPageTable[s] || @adrPageTable[s.to_s])
      return result 
    end
    
    raise "BindingMaker unable to evaluate #{s}"
  end
  def getBinding(); return binding(); end
  def initialize(thePageMaker)
    @thePageMaker = thePageMaker # so we can access it later
    @adrPageTable = thePageMaker.adrPageTable # so macros can get at it
    @theHtmlDispatcher = HtmlDispatcher.new(self) # assistant
  end
  attr_reader :thePageMaker
end

=begin superclass from which outline renderers are to inherit
this allows outline renderers to enjoy the same environment as macro evaluation (see on BindingMaker, above)
(this is not a Frontier feature, but it sure should be! makes life a lot easier;
e.g. you can reach @adrPageTable, tools, Html methods really easily)
so, an outline renderer must be in module UserLand::Renderers and must be a class deriving from SuperRenderer
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
    @theBindingMaker.method_missing(s, *args)
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
    adrObject = Pathname.new(adrObject).expand_path
    raise "No such file #{adrObject}" unless adrObject.exist?
    raise "File #{adrObject} not a site page" unless self.everyPageOfSite(adrObject).include?(adrObject)
  end
  def self.releaseRenderedPage(adrObject, flPreview = true)
    time = Time.new.to_f
    
    adrObject = Pathname.new(adrObject).expand_path
    self.guaranteePageOfSite(adrObject) # validity check
    
    # TODO: omitting "extra templates" logic
    
    adrStorage = callFileWriterStartup(adrObject) # adrStorage is unused at present
          
    pm = PageMaker.new
    pm.buildObject(adrObject)
    puts "page built in #{Time.new.to_f - time} seconds"
    
    pm.writeFile
    
    # TODO: omitting file writer shutdown mechanism
    # callFileWriterShutdown(adrObject, adrStorage)
    
    pm.saveOutAutoglossary # save out autoglossary if any
    
    if flPreview && (File.extname(pm.adrPageTable[:fname]) =~ /\.htm/i) # supposed to be a test for browser displayability
      if pm.adrPageTable[:ftpsite][:apacheURL]
        f = pm.adrPageTable[:f].relative_path_from(Pathname.new(pm.adrPageTable[:ftpsite][:apacheSite]).expand_path)
        `open #{URI.escape(pm.adrPageTable[:ftpsite][:apacheURL] + f)}`
      else
        `open file://#{URI.escape(pm.adrPageTable[:f].to_s)}`
      end
    end
    
  end
  def self.publishSite(adrObject, preflight=true)
    adrObject = Pathname.new(adrObject).expand_path
    self.preflightSite(adrObject) if preflight
    self.everyPageOfSite(adrObject).each_with_index do |p, i|
      puts "publishing #{p}"
      self.releaseRenderedPage(p, (p == adrObject)) # the only one to open in browser is the one we started with
      #break if i > 5 # profiling
    end
  end
  def self.getFtpSiteFile(p)
    # walk upwards to the first folder containing an #ftpSite file, and return that file
    # if what you wanted was the folder itself, just call the folder's dirname
    Pathname.new(p).dirname.ascend do |dir|
      dir.each_entry do |f|
        if "#ftpsite" == f.simplename.to_s.downcase
          return dir + f
        end
      end
      raise "Reached top level without finding #ftpsite" if dir.root?
    end
  end
  def self.everyPageOfFolder(f)
    # a page is anything in the folder not starting with # or inside a folder starting with #
    # that doesn't mean every page is a renderable; it might merely be a copyable, but it is still a page
    # "in" means at any depth
    result = Array.new
    Pathname.new(f).find do |p|
      Find.prune if p.basename.to_s =~ /^[#.]/
      result << p if (!p.directory? && p.simplename != "") # ignore invisibles
    end
    return result
  end
  class << self; memoize :everyPageOfFolder; end # have to talk this way yadda yadda
  def self.everyPageOfSite(adrObject)
    return everyPageOfFolder(getFtpSiteFile(adrObject).dirname)
  end
  def self.preflightSite(adrObject)
    # prebuild autoglossary using every page of table containing adrObject path
    glossary = Hash.new
    pm = nil # so that we have a PageMaker object left over at the end
    self.everyPageOfSite(Pathname.new(adrObject)).each do |p|
      pm = PageMaker.new
      pm.memoize = false # so if we then publishSite, existing values won't bite us
      pm.buildPageTableFully(p)
      tempGlossary = Hash.new
      pm.addPageToGlossary(p, tempGlossary)
      # merge by hand watching for non-uniques
      tempGlossary.each do |k,v|
        if glossary[k] && v != glossary[k]
          puts "----\nNon-unique autoglossary entry detected for #{k}\n#{v.inspect} vs.\n#{glossary[k].inspect}\nprocessing #{p}"
        end
        glossary[k.downcase] = v
      end
    end
    pm.saveOutAutoglossary(glossary) # save out resulting autoglossary
  end  
  def self.callFileWriterStartup(adrObject, adrStorage=Hash.new)
    # fill in adrStorage and return it
    ftpsite = getFtpSiteFile(adrObject)
    ftpsiteHash = YAML.load_file(ftpsite)
    adrStorage[:adrftpsite] = ftpsite
    adrStorage[:method] = ftpsiteHash[:method]
    adrStorage = LCHash.new.merge(adrStorage) # convert to an LCHash so lowercase keys work
    return adrStorage
  end
  def self.getLink(linetext, url)
    return %{<a href="#{url}">#{linetext}</a>}
  end
  def self.newSite()
    s = `#{ENV['TM_SUPPORT_PATH']}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog filesave --title "New Web Site" --text "Specify a folder to create"`
    exit if s == "" # user cancelled
    p = Pathname.new(s.chomp)
    p.mkpath
    FileUtils.cp_r($newsite.to_s + '/.', p)
    FileUtils.rm((p + "#autoglossary.yaml").to_s) # just causes errors if it's there
    sup = ENV['TM_SUPPORT_PATH']
    `"#{sup}/bin/mate" '#{p}'`
  end
  def self.traverseLink(adrObject, linktext)
    autoglossary = (callFileWriterStartup(Pathname.new(adrObject)))[:adrFtpSite].dirname + "#autoglossary.yaml"
    if autoglossary.exist?
      entry = LCHash.new.merge(YAML.load_file(autoglossary.to_s))[linktext.downcase]
      if entry && entry[:adr]
        sup = ENV['TM_SUPPORT_PATH']
        `"#{sup}/bin/mate" '#{entry[:adr]}'`
        exit
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
    adrPageTable.each do |k,v|
      k = k.to_s
      if k =~ /^meta./i # key should start with "meta" but not *be* "meta"
        if k =~ /^metaequiv/i
          type, metaName = "http-equiv", k[9..-1]
        else
          type, metaName = "name", k[4..-1]
        end
        htmlText << %{\n<meta #{type}="#{metaName}" content="#{v}" />}
      end
    end
    
    # opportunity to insert anything whatever into head section
    # TODO: revise so that more than one insertion is possible?
    htmlText << "\n" + adrPageTable[:meta] if adrPageTable[:meta]
    
    # allow for possibility that <meta /> syntax is illegal, as in html
    htmlText = htmlText.gsub("/>",">") if htmlstyle
    return htmlText
  end
  def bodytag(adrPageTable=@adrPageTable) # generate body tag
    htmltext = ""
    
    # background image, drawn from background directive
    if s = adrPageTable["background"] or s = adrPageTable[:background]
      htmltext += %{ background="#{getImageData(s, adrPageTable)[:url]}" } rescue ""
    end

    # other body tag attributes, drawn from directives
    # really should not be using this feature! this is what CSS is for
    # still, it's legal, and traditional in Frontier
    attslist = %w{bgcolor alink vlink link 
      text topmargin leftmargin marginheight 
      marginwidth onload onunload
    }
    attslist.each do |oneatt|
      if s = adrPageTable[oneatt] or s = adrPageTable[oneatt.to_sym]
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
        htmltext += %{ #{oneatt}="#{s}"}
      end
    end 
    return "<body#{htmltext}>"
  end
  def linkstylesheet(sheetName, adrPageTable=@adrPageTable) # link to one stylesheet
    # you really ought to use linkstylesheets instead, it calls this for you
    # Frontier's logic for finding the style sheet is much more complex
    # I just assume we have a #stylesheets folder containing .css files
    # and I also just assume we'll write it into a folder called "stylesheets" at top level
    # note that in my implementation, although you *can* call this in a macro, you shouldn't;
    fname = sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".css"
    sheetLoc = adrPageTable[:siteRootFolder] + Pathname.new("stylesheets/#{fname}")
    source = adrPageTable["stylesheets"] + Pathname.new("#{sheetName}.css")
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    # write out the stylesheet if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing css (#{sheetName})!"
      FileUtils.cp(source, sheetLoc, :preserve => true)
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    return %{<link rel="stylesheet" href="#{pageToSheet}" type="text/css" />\n}
  end
  def embedstylesheet(sheetName, adrPageTable=@adrPageTable) # embed stylesheet
    # as with linkstylesheet, unlike Frontier, my logic for finding the stylesheet is very simplified
    # must be in #stylesheets folder as css file, end of story
    source = adrPageTable["stylesheets"] + Pathname.new("#{sheetName}.css")
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    s = File.read(source)
    return %{\n<style type="text/css">\n<!--\n#{s}\n-->\n</style>\n}
  end
  def imageref(imagespec, options=Hash.new, adrPageTable=@adrPageTable) # create img tag
    # finding the image, copying it out, and obtaining its height and width and relative url...
    # is the job of getImageData
    imageTable = getImageData(imagespec, adrPageTable)
    options = Hash.new if options.nil? # become someone might pass nil
    height = options[:height] || imageTable[:height]
    width = options[:width] || imageTable[:width]
    htmlText = %{<img src="#{imageTable[:url]}" }
    # added :nosize to allow suppression of width and height
    htmlText += %{width="#{width}" height="#{height}" } unless (!width && !height) || options[:nosize]
    %w{name id alt hspace vspace align style class title border}.each do |what|
      htmlText += %{ #{what}="#{options[what.to_sym]}" } if options[what.to_sym]
    end
    
    # some attributes get special treatment
    # usemap, must start with #
    if (usemap = options[:usemap])
      usemap = ("#" + usemap).squeeze("#")
      htmlText += %{ usemap="#{usemap}" }
    end
    if options[:ismap]
      htmlText += ' ismap="ismap" '
    end
    # lowsrc, not supported (not valid HTML any more)
    #if (lowsrc = options[:lowsrc])
    #  htmlText += %{ lowsrc="#{getImageData(lowsrc, adrPageTable)[:url]}" }
    #end
    if (rollsrc = options[:rollsrc])
      htmlText += %{ onmouseout="this.src='#{imageTable[:url]}'" }
      htmlText += %{ onmouseover="this.src='#{getImageData(rollsrc, adrPageTable)[:url]}'" }
    end
    # explanation, we now use "alt"; anyhow, there *must* be one
    unless options[:alt]
      htmlText += %{ alt="image" }
    end
    htmlText += " />"
    # neaten
    htmlText = htmlText.squeeze(" ")
    # glossref, wrap whole thing in link ready for normal handling
    # unlikely (manual <a> is way better) but someone might want to use it
    if (glossref = options[:glossref])
      htmlText = %{<a href="#{glossref}">#{htmlText}</a>}
    end
    return htmlText
  end
  def pageheader(adrPageTable=@adrPageTable) # generate standard page header from html tag to body tag
    # if pageheader directive exists, assume macro was explicitly called in error
    # cool because template can contain pageheader() call with or without #pageheader directive elsewhere
    return "" if ( adrPageTable[:pageheader] || adrPageTable["pageheader"] )
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
  def linkjavascripts(adrPageTable=@adrPageTable) # link to all javascripts requested in directives
    # not in Frontier at all, but clearly a mechanism like this is needed
    # works like "meta", allowing multiple javascriptXXX directives to ask that we link to XXX
    s = ""
    adrPageTable.keys.each do |k| # values are irrelevant, all the info is in the key name
      k = k.to_s
      if k =~ /^javascript./i # key should start with "javascript" but not *be* "javascript"
        if k.downcase != "javascripts" # "javascripts" is special, it's the folder of scripts
          s += linkjavascript(k[10..-1], adrPageTable)
        end
      end
    end
    return s
  end
  def linkstylesheets(adrPageTable=@adrPageTable) # link to all stylesheets requested in directives
    # call this, not linkstylesheet; it lets you link to multiple stylesheets
=begin
    # old way, no longer used
    # works just like linkjavascripts
    s = ""
    adrPageTable.keys.each do |k|
      k = k.to_s
      if k =~ /^stylesheet./i
        if k.downcase != "stylesheets"
          s += linkstylesheet(k[10..-1], adrPageTable)
        end
      end
    end
=end
    # new way, we maintain a "linkstylesheets" array
    # reason: with CSS, order matters
    # see incorporateDirective() for how the "linkstylesheets" array gets constructed
    s = ""
    if adrPageTable[:linkstylesheets]
      adrPageTable[:linkstylesheets].each do |name|
        s += linkstylesheet(name, adrPageTable)
      end
    end
    return s
  end
  def linkjavascript(sheetName, adrPageTable=@adrPageTable) # link to one javascript
    # you really ought to use linkjavascripts instead, it calls this for you
    # as with linkstylesheet, my logic is very simplified:
    # I just assume we have a #javascripts folder and we write to top-level "javascripts"
    fname = sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".js"
    sheetLoc = adrPageTable[:siteRootFolder] + Pathname.new("javascripts/#{fname}")
    source = adrPageTable["javascripts"] + Pathname.new("#{sheetName}.js")
    raise "javascript #{sheetName} does not seem to exist" unless source.exist?
    # write out the javascript if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing javascript (#{sheetName})!"
      FileUtils.cp(source, sheetLoc, :preserve => true)
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    return %{<script src="#{pageToSheet}" type="text/javascript" ></script>\n}
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
    # no error-checking; we assume this object is in a site
    [".txt", ".opml", ".rb"].include?(Pathname.new(adrObject).extname)
  end
  def writeFile(adrStorage=nil, s=@adrPageTable[:renderedtext], adrPageTable=@adrPageTable)
    # eventually we might support ftp like Frontier, but right now we just write to disk
    # so the adrStorage parameter isn't being used for anything yet
    f = adrPageTable[:f] # target file
    # error check; make certain we are not about to write into ourself
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
        Sandbox.new(adrFilter).send(filter_name, adrPageTable)
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
    # all outline renderers in tools spring into life
    theBindingMaker = BindingMaker.new(self)
    begin
      v = nil
      adrPageTable["tools"].each { |k,v| theBindingMaker.instance_eval(File.read(v)) }
    rescue SyntaxError
      raise "Trouble reading #{v}"
    end
  
    # if the page is an outline or script, now render it (unlike Frontier which did it earlier, unnecessarily)
    case adrPageTable[:bodytext]
    when Opml # outline!
      # renderer is expected to be a subclass of SuperRenderer within module UserLand::Renderers
      # can be defined in user.rb, or as an .rb file in tools 
      # it should not override initialize, and must accept render with 1 arg (an Opml object)
      begin
        renderer_klass = UserLand::Renderers.module_eval(adrPageTable[:renderoutlinewith]) 
      rescue 
        raise "Renderer #{adrPageTable[:renderoutlinewith]} not found!"
      end
      adrPageTable[:bodytext] = renderer_klass.new(self, theBindingMaker).render(adrPageTable[:bodytext])
    when Sandbox # script!
      # must have a render() method, we call it in a sandbox, handing it the whole PageMaker object
      # after that, dude, you're on your own!
      adrPageTable[:bodytext] = adrPageTable[:bodytext].render(self)
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
    # a snippet is a .txt file in a #tools folder
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
    # TODO: no support yet for indirect template
    # named template supported, assumed to be in #templates or user/templates
    # if named, it will be :template, a string; if found, it will be "template", a Pathname
    raise "No template found or specified" unless (adrTemplate = (adrPageTable[:template] || adrPageTable["template"]))
    if adrTemplate.kind_of?(String) # named template
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
    s = runDirectives(adrTemplate)
    # TODO: omitting stuff about revising if #fileExtension was changed by template
      
    # if we have no title by now, that's an error
    raise "You forgot to give this page a title!" unless adrPageTable[:title]
    
    # embed page into template at <bodytext>
    # I've cut Frontier's <title> substitution feature, it saves nothing and leads to error
    # important to write it as follows or we get possibly unwanted \\, \1 substitution
    s = s.sub(/<bodytext>/i) {|x| adrPageTable[:bodytext]}
      
    # macros
    s = processMacros(s, theBindingMaker.getBinding) unless !getPref("processmacros")
  
    # glossary expansion; my equivalent is to look for already existing <a href...> tags
    # ...generated no matter how, e.g. manually, with getLink, with markdown [](), whatever
    # to count as a candidate, must be clearly "local"
    # we can resolve identifiers in user glossary or our autoglossary (see refGlossary)... 
    s = s.gsub /<a href="(.*?)"(.*?)>/i do |ref|
      retval = ref # if nothing else, just return what we came in with
      href = $1
      rest = $2
      # if contains dot or colon-slash-slash, or starts with #, assume this is a real URL, don't touch
      # but user can override the first two checks by escaping
      unless href =~ /[^\\]\./ || href =~ %r{[^\\]\://} || href =~ /^#/
        if href =~ /([^\\])\^/ # remote-site semantics
          # we look up id in autoglossary of another "site" 
          # (use site^id to specify, where "site" is relative filepath in glossary)
          begin
            id = $'
            path = refGlossary($` + $1).match(/href="(.*?)"/)[1]
            path = (adrPageTable[:adrSiteRootTable] + Pathname.new(path)).cleanpath + "#autoglossary.yaml"
            h = LCHash.new.merge(YAML.load_file(path))
            #puts "h:"
            #pp h
            url = %{<a href="#{h[id.gsub('\\','')][:url]}">}
            #puts "url:"
            #p url
            #TODO: failing to notice/barf if there is no url entry in the hash
          rescue
            puts "Remote glossary lookup failed on #{href}, apparently while processing #{adrPageTable[:adrObject]}"
          end
        else
          href = href.gsub('\\','') # remove user escaping if any
          url = refGlossary(href)
        end
        if url
          retval = url
        else # refGlossary failed, insert dummy but legal URL
          retval = "<a href=\"errorRefGlossaryFailedHere\">"
        end
        # refGlossary will create a complete new <a> tag (not sure if that's wise, but it's what I'm doing)...
        # ...so, if they have stuff after the href, we have hung on to it, restore it now 
        retval[-1] = rest + ">" # restore stuff after href tag, if any
      end
      retval
    end
  
    # pageHeader attribute or result of pageheader() standardmacro call instead
    # we don't handle this until now, because other stuff might need to influence title or bgcolor or something
    # might be named (symbol key) or found (string key); might be direct string or indirect pathname
    if ph = adrPageTable[:pageheader] or ph = adrPageTable["pageheader"]
      ph = File.read(adrPageTable["pageheader"]) if ph.kind_of?(Pathname)
      s = processMacros(ph, theBindingMaker.getBinding) + s
    end
  
    # linefeed thing, not implemented
    # fatpages, not implemented
  
    adrPageTable[:renderedtext] = s
    
    # finalfilter, handed adrPageTable, expected to access :renderedtext
    callFilter("finalFilter")
  
  end
  def buildPageTableFully(adrObject, adrPageTable=@adrPageTable)
    # this has no exact Frontier analog; it's the first few lines of buildObject
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
    
    # work out :fname, :siteRootFolder, :subDirectoryPath, :f
    # :fname => name of file we will write out
    # :siteRootFolder => folder into which all pages will be written
    # :adrSiteRootTable => folder containing #ftpsite marker, in which whole site object lives
    # :f => full pathname of file we will write out
    # :subDirectoryPath => relative path from :siteRootFolder to :f, or from :adrSiteRootTable to :adrObject
    if renderable?(adrPageTable[:adrobject])
      adrPageTable[:fname] = getFileName(adrPageTable[:adrobject].simplename)
    else
      adrPageTable[:fname] = adrPageTable[:adrobject].basename
    end
    folder = getSiteFolder() # sets adrPageTable[:siteRootFolder] and returns it
    relpath = (adrPageTable[:adrobject].relative_path_from(adrPageTable[:adrSiteRootTable])).dirname
    adrPageTable[:subdirectorypath] = relpath
    adrPageTable[:f] = folder + relpath + adrPageTable[:fname]
    #pp adrPageTable
    
    # insert user glossary
    if UserLand::User.respond_to?(:glossary)
      g = adrPageTable["glossary"]
      UserLand::User.glossary().each do |k,v|
        g[k.downcase] = v unless g[k]
      end
    end
  end
  def buildPageTable(adrObject, adrPageTable=@adrPageTable)
   # puts "====", "buildPageTable called: #{self}", adrObject, "===="
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
    # if it is a #tools folder, hash pathnames under simple filenames
    # if it is #prefs or #glossary, load as a yaml hash and merge with existing hash
    # if it is #ftpsite, determine root etc.
    # else, just hash pathname under simple filename
    catch (:done) do
      found_ftpsite = false
      adrObjectDir.ascend do |dir|
        dir.each_entry do |f|
          if /^#/ =~ f
            case f.simplename.to_s.downcase
            when "#tools" # gather tools into tools hash; new feature (non-Frontier), .txt files go into snippets hash
              (dir + f).each_entry do |ff|
                unless /^\./ =~ (tool_simplename = ff.simplename.to_s.downcase)
                  case ff.extname
                  when ".rb"
                    adrPageTable["tools"][tool_simplename] ||= dir + f + ff
                  when ".txt"
                    adrPageTable["snippets"][tool_simplename] ||= File.read(dir + f + ff)
                  end
                end
              end
            when "#images" # gather references to images into images hash, similar to tools
              (dir + f).each_entry do |ff|
                unless /^\./ =~ (im_simplename = ff.simplename.to_s.downcase)
                  adrPageTable["images"][im_simplename] ||= dir + f + ff
                end
              end
            when "#prefs" # flatten prefs out into top-level entries in adrPageTable
              prefsHash = YAML.load_file(dir + f)
              # prefsHash.each_key {|key| adrPageTable[key] ||= prefsHash[key]}
              prefsHash.each_key {|key| incorporateDirective(key, prefsHash[key], true, adrPageTable)}
            when "#glossary" # gather glossary entries into glossary hash: NB these are *user* glossary entries
              # (different from Frontier: automatically generated glossary entries for linking live in #autoglossary)
              glossHash = LCHash.new.merge(YAML.load_file(dir + f))
              adrPageTable["glossary"] = glossHash.merge(adrPageTable["glossary"]) # note order: what's in adrPageTable overrides
            when "#ftpsite"
              found_ftpsite = true
              adrPageTable[:ftpsite] ||= YAML.load_file(dir + f)
              adrPageTable[:adrsiteroottable] ||= dir
              #adrPageTable[:subDirectoryPath] ||= (adrObject.relative_path_from(dir)).dirname
            else
              adrPageTable[f.simplename.to_s[1..-1]] ||= (dir + f) # pathname TODO: should I lowercase this key?
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
    # url-setting and some other stuff (fname, f) not yet written
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
    k,v = linetext.split(" ",2)
    #adrPageTable[k.to_sym] = eval(v.chomp) 
    incorporateDirective(k.to_sym, eval(v.chomp), false, adrPageTable)
  rescue SyntaxError
    raise "Syntax error: Failed to evaluate directive #{v.chomp}"
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
    return normalizeName(n) + getPref("fileextension", adrPageTable)
  end
  def normalizeName(n, adrPageTable=@adrPageTable)
    n = n.to_s
    n = n.dropNonAlphas if getPref("dropnonalphas", adrPageTable)
    n = n.downcase if getPref("lowercasefilenames", adrPageTable)
    return n[0, getPref("maxfilenamelength", adrPageTable) - getPref("fileextension", adrPageTable).length]
  end
  def getSiteFolder(adrPageTable=@adrPageTable)
    # where shall we render/copy pages into? set :siteRootFolder and return it as well
    return adrPageTable[:siteRootFolder] if adrPageTable[:siteRootFolder]
    folder = Pathname.new(adrPageTable[:ftpsite][:folder]).expand_path
    # ensure whole containing path exists; if not, use temp folder
    folder = Pathname.new(`mktemp -d /tmp/website.XXXXXX`) unless folder.dirname.exist?
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
      url = adrPageTable[:ftpsite][:url]
      url += "/" unless url =~ %r{/$}
      uri = URI::join(url, URI::escape(h[:path].to_s))
      h[:url] = uri.to_s
    rescue
    end
    # put into autoglossary hash, possibly twice
    glossary[adrPageTable[:f].simplename.to_s.downcase] = h
    glossary[linetext.downcase] = h if linetext
  end
  def processMacros(s, theBinding, adrPageTable=@adrPageTable)
    # process macros; the Ruby equivalent is to use ERB, so we do
    # reference munging like Frontier's is done in the BindingMaker class
    return ERB.new(s).result(theBinding)
  end
  def refGlossary(name, adrPageTable=@adrPageTable)
    # return a complete <a> tag referring to the named target from where we are, or nil
    # Frontier merely substitutes a glossPath at this stage, but I don't see the need for that
    # as usual I am leaving out a certain amount of Frontier's logic here
    # also I'm departing from Frontier's logic: we have two hashes to look in:
    # "glossary" is user glossary of name-substitution pairs
    # :autoglossary is our glossary of hashes pointing to pages we have built
    # new (non-Frontier) logic: if name contains #, split into name and anchor, search, reassemble
    name, anchor = name.split("#", 2)
    anchor = anchor ? "#" + anchor : ""
    # autoglossary
    g = LCHash.new.merge(adrPageTable[:autoglossary])
    if g && g[name] && g[name][:path]
      path = adrPageTable[:siteRootFolder] + g[name][:path]
      return %{<a href="#{path.relative_uri_from(adrPageTable[:f])}#{anchor}">} 
    end
    # user glossary
    g = adrPageTable["glossary"]
    if g && g[name]
      return %{<a href="#{g[name]}#{anchor}">}
    end
    # report failure
    puts "RefGlossary failed on #{name}, apparently while processing #{adrPageTable[:adrObject]}"
    return nil
  end
  def getOneDirective(directiveName, adrObject)
    # simple-mindedly pull a directive out of a page's contents
    # we now accept an array of directives, and if so, we return an array
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
    # return array of two identfiers, namely the prev and next renderable page at this level
    # ids suitable for use in autoglossary consultation
    # if there is a #nextprevs listing ids in order, we just use that
    # otherwise we use the physical file system
    # either or both element of the array can be nil to signify none
    # result = [nil, nil]
    # sibs = pagesInFolder(obj.dirname)
    # us = sibs.index(obj.simplename.to_s)
    # result[0] = sibs[us-1] if us > 0
    # result[1] = sibs[us+1] if us < sibs.length - 1
    # return result
    pagesInFolder(obj.dirname).nextprev(obj.simplename.to_s)
  end
  def pagesInFolder(folder, adrPageTable=@adrPageTable)
    # utility, also useful to macros
    # return array of identifiers of renderables in folder
    # these identifiers are suitable for use in getTitleAndPath and other autoglossary consultation
    # if there is a #nextprevs, the array is ordered as in the nextprevs
    # otherwise we just use alphabetical order (filesystem)
    # return nil if no result
    # memoized, since #nextprevs and folder contents unlikely to change during a rendering
    # third parameter gives a chance to cancel this (hard to see why you'd want to)
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
    # Frontier has fu for seeking the image, but I assume a single "images" hash gathered as we build page table
    raise "No 'images' folder found" unless adrPageTable["images"]
    imagePath = adrPageTable["images"][imageSpec]
    raise "Image #{imageSpec} not found" unless imagePath
    # I also assume single folder at top level (but I leave folder name as a pref)
    imagesFolder = adrPageTable[:siteRootFolder] + getPref("imagefoldername", adrPageTable)
    # actually write the image; I've always thought this is an inappropriate place to do this...
    # ... and would eventually like to change it
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

if __FILE__ == $0
  
# UserLand::Html::releaseRenderedPage("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/fourwindowsfolder/adbk.txt")
# UserLand::Html::preflightSite("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/appmodes.txt")
# UserLand::Html::releaseRenderedPage("./scriptde.txt")
# UserLand::Html::preflightSite(Pathname.new("./scriptde.txt").expand_path)
# UserLand::Html::publishSite("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/appmodes.txt")
# UserLand::Html::releaseRenderedPage("./scriptdefolder/develop.txt")
# pp UserLand::Html::everyPageOfSite(Pathname.new("/Volumes/gromit/Users/matt2/anger/Word Process/web sites/emperorWebSite/site/default2.opml").expand_path)
#UserLand::Html::newSite()
#UserLand::Html::releaseRenderedPage("/Volumes/gromit/Users/matt2/anger/Word Process/emperorWebSite/site/default2.opml")
#require 'profiler'
#Profiler__::start_profile
#UserLand::Html::releaseRenderedPage("/Volumes/gromit/Users/matt2/anger/Word Process/web sites/emperorWebSite/site/default2.opml")
#Profiler__::print_profile($stdout)
Profiler__::start_profile
UserLand::Html::publishSite("/Volumes/gromit/Users/matt2/anger/Word Process/jobs/sd45/sd45docs/scriptde.txt")
Profiler__::print_profile($stdout)

end
