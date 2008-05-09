require "pathname"
require "yaml"
require "erb"
require "pp"
require "uri"

class String # convenience methods
  def dropNonAlphas
    return self.gsub(/[^a-zA-Z0-9_]/, "")
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
    end
  end
end

=begin make 'load' and 'require' include folder next to, and with same name as, this file 
that is where supplementary files go:
(1) stuff to keep this file from getting too big
(2) user.rb, where the user can maintain the UserLand::User class
=end
p = Pathname.new(__FILE__)
$: << (p.dirname + p.simplename).to_s
$usertemplates = (p.dirname + p.simplename) + "user" + "templates"
$newsite = (p.dirname + p.simplename) + "newsite"

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

# now that we've defined SuperRenderer, we can load "user.rb", which might contain renderers inheriting from it
require 'opml'
begin; require 'user'; rescue; end # no penalty for not having a "user.rb" file 

# public interface for rendering a page (class methods)
# also general utilities without reference to any specific page being rendered
module UserLand::Html
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
      `open 'file://#{ERB::Util::url_encode(pm.adrPageTable[:f]).gsub("%2F", "/")}'`
    end
    
  end
  def self.publishSite(adrObject, preflight=true)
    adrObject = Pathname.new(adrObject).expand_path
    self.preflightSite(adrObject) if preflight
    self.everyPageOfSite(adrObject).each do |p|
      puts "publishing #{p}"
      self.releaseRenderedPage(p, (p == adrObject)) # the only one to open in browser is the one we started with
    end
  end
  def self.everyPageOfSite(adrObject)
    # a page is anything in the site table not starting with # or inside a folder starting with #
    # that doesn't mean every page is a renderable; it might merely be a copyable, but it is still a page
    result = Array.new
    (callFileWriterStartup(Pathname.new(adrObject)))[:adrFtpSite].dirname.find do |p|
      Find.prune if p.basename.to_s =~ /^[#.]/
      result << p if (!p.directory? && p.simplename != "") # ignore invisibles
    end
    return result
  end
  def self.preflightSite(adrObject)
    # prebuild autoglossary using every page of table containing adrObject path
    glossary = Hash.new
    pm = nil # so that we have a PageMaker object left over at the end
    self.everyPageOfSite(Pathname.new(adrObject)).each do |p|
      pm = PageMaker.new
      pm.buildPageTableFully(p)
      pm.addPageToGlossary(p)
      # merge by hand watching for non-uniques
      pm.adrPageTable[:autoglossary].each do |k,v|
        if glossary[k] && v != glossary[k]
          puts "----\nNon-unique autoglossary entry detected for #{k}\n#{v.inspect} vs.\n#{glossary[k].inspect}\nprocessing #{p}"
        end
        glossary[k] = v
      end
    end
    pm.saveOutAutoglossary(glossary) # save out resulting autoglossary
  end  
  def self.callFileWriterStartup(adrObject, adrStorage=Hash.new)
    # we require an #ftpSite file to mark the top of the site
    # walk upwards until we find it; fill in adrStorage and return it
    ftpsite = nil
    catch :done do
      adrObject.dirname.ascend do |dir|
        dir.each_entry do |f|
          if "#ftpsite" == f.simplename.to_s.downcase
            ftpsite = dir + f; throw :done;
          end
        end
        raise "Reached top level without finding #ftpsite" if dir.root?
      end
    end
    ftpsiteHash = File.open(ftpsite) {|io| ftpsiteHash = YAML.load(io)}
    adrStorage[:adrFtpSite] = ftpsite
    adrStorage[:method] = ftpsiteHash[:method]
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
    `mate '#{p}'`
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
    if getPref("includeMetaCharset", adrPageTable)
      htmlText << %{\n<meta http-equiv="content-type" content="text/html; charset=#{getPref("charset", adrPageTable)}" />}
    end
    
    # generator
    if getPref("includeMetaGenerator", adrPageTable)
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
    fname = sheetName[0, getPref("maxFileNameLength", adrPageTable)] + ".css"
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
    return %{<link rel="stylesheet" href="#{pageToSheet}" type="text/css" />}
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
    htmlText = %{<img src="#{imageTable[:url]}" width="#{width}" height="#{height}" }
    %w{name id alt hspace vscape align style class title border}.each do |what|
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
<biteme>
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
    return s
  end
  def linkjavascript(sheetName, adrPageTable=@adrPageTable) # link to one javascript
    # you really ought to use linkjavascripts instead, it calls this for you
    # as with linkstylesheet, my logic is very simplified:
    # I just assume we have a #javascripts folder and we write to top-level "javascripts"
    fname = sheetName[0, getPref("maxFileNameLength", adrPageTable)] + ".js"
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
  attr_reader :adrPageTable
  def initialize(adrPageTable = Hash.new)
    @adrPageTable = adrPageTable
  end
  def renderable?(adrObject)
    # no error-checking; we assume this object is in a site
    [".txt", ".opml", ".rb"].include?(Pathname.new(adrObject).extname)
  end
  def writeFile(adrStorage=nil, s=@adrPageTable[:renderedtext], adrPageTable=@adrPageTable)
    # eventually we might support ftp like Frontier, but right now we just write to disk
    # so the adrStorage parameter isn't being used for anything yet
    f = adrPageTable[:f] # target file
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
    adrPageTable["tools"].each { |k,v| theBindingMaker.instance_eval(File.read(v)) }
  
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
        $&
      end
    end
          
    # pagefilter, handed adrPageTable, expected to access :bodytext
    callFilter("pageFilter")

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
            h = File.open(path) {|io| YAML.load(io)}
            url = %{<a href="#{h[id.gsub('\\','')][:url]}">}
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
    adrPageTable[:bodytext] = tenderRender(adrObject)
    
    # work out :fname, :siteRootFolder, :subDirectoryPath, :f  
    if renderable?(adrObject)
      adrPageTable[:fname] = getFileName(adrObject.simplename)
    else
      adrPageTable[:fname] = adrObject.basename
    end
    folder = getSiteFolder() # sets :siteRootFolder and returns it
    relpath = (adrObject.relative_path_from(adrPageTable[:adrSiteRootTable])).dirname
    adrPageTable[:subDirectoryPath] = relpath
    adrPageTable[:f] = folder + relpath + adrPageTable[:fname]
  
    # insert user glossary
    if UserLand::User.respond_to?(:glossary)
      g = adrPageTable["glossary"]
      UserLand::User.glossary().each do |k,v|
        g[k] = v unless g[k]
      end
    end
  end
  def buildPageTable(adrObject, adrPageTable=@adrPageTable)
    # record what object is being rendered
    adrPageTable[:adrObject] = adrObject
    
    # init hashes to gather stuff into as we walk up the hierarchy
    adrPageTable["tools"] = Hash.new
    adrPageTable["glossary"] = Hash.new
    adrPageTable["snippets"] = Hash.new
  
    # walk file hierarchy looking for things that start with "#"
    # add things only if they don't already exist; that way, closest has precedence
    # if it is a #tools folder, hash pathnames under simple filenames
    # if it is #prefs or #glossary, load as a yaml hash and merge with existing hash
    # if it is #ftpsite, determine root etc.
    # else, just hash pathname under simple filename
    catch (:done) do
      found_ftpsite = false
      adrObject.dirname.ascend do |dir|
        dir.each_entry do |f|
          if /^#/ =~ f
            case f.simplename.to_s.downcase
            when "#tools" # gather tools into tools hash; new feature (non-Frontier), .txt files go into snippets hash
              (dir + f).each_entry do |ff|
                unless /^\./ =~ (tool_simplename = ff.simplename.to_s)
                  case ff.extname
                  when ".rb"
                    adrPageTable["tools"][tool_simplename] ||= dir + f + ff
                  when ".txt"
                    adrPageTable["snippets"][tool_simplename] ||= File.read(dir + f + ff)
                  end
                end
              end
            when "#prefs" # flatten prefs out into top-level entries in adrPageTable
              prefsHash = File.open(dir + f) {|io| YAML.load(io)}
              prefsHash.each_key {|key| adrPageTable[key] ||= prefsHash[key]}
            when "#glossary" # gather glossary entries into glossary hash: NB these are *user* glossary entries
              # (different from Frontier: automatically generated glossary entries for linking live in #autoglossary)
              glossHash = File.open(dir + f) {|io| YAML.load(io)}
              adrPageTable["glossary"] = glossHash.merge(adrPageTable["glossary"]) # note order: what's in adrPageTable overrides
            when "#ftpsite"
              found_ftpsite = true
              adrPageTable[:ftpsite] ||= dir + f
              adrPageTable[:adrSiteRootTable] ||= dir
              #adrPageTable[:subDirectoryPath] ||= (adrObject.relative_path_from(dir)).dirname
            else
              adrPageTable[f.simplename.to_s[1..-1]] ||= (dir + f) # pathname
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
      File.open(adrGlossTable) {|io| YAML.load(io)}
    else
      Hash.new
    end
    # url-setting and some other stuff (fname, f) not yet written
    # there is an inefficiency in Frontier here: this is all done again after tenderRender
    # so I'm just omitting it here for now
  end
  # GOT TO HERE
  def tenderRender(adrObject, adrPageTable=@adrPageTable)
    case File.extname(adrObject)
    when ".txt"
      return runDirectives(adrObject)
    when ".opml"
      return runOutlineDirectives(adrObject)
    when ".rb"
      return Sandbox.new(adrObject)
    else
      return ""
    end
  end
  def runDirectives(adrObject, adrPageTable=@adrPageTable)
    lines = []
    File.open(adrObject) do |io|
      keep_looking = true
      while io.gets
        if keep_looking && $_[0,1] == "#"
          runDirective($_[1..-1], adrPageTable)
        else
          lines << $_
          keep_looking = false
        end
      end
    end
    return lines.join("")
  end
  def runOutlineDirectives(adrObject, adrPageTable=@adrPageTable)
    #s = File.open(adrObject) {|io| io.read}
    #op = Opml.new(s)
    # hmmm, new LibXML implementation requires a different kind of "new..." Maybe I should fix this mismatch
    op = Opml.new(adrObject.to_s)
    aline = op.getLineText
    while aline[0,1] == "#"
      runDirective(aline[1..-1], adrPageTable)
      op.deleteLine
      aline = op.getLineText
    end
    return op
  end
  def runDirective(linetext, adrPageTable=@adrObject)
    k,v = linetext.split(" ",2)
    adrPageTable[k.to_sym] = eval(v.chomp) # should error-check!
  end
  def getFileName(n, adrPageTable=@adrPageTable, adrObject=nil)
    #fileExtension = ".html" # should in fact use getPref
    fileExtension = getPref("fileextension")
    return normalizeName(n) + fileExtension
  end
  def normalizeName(n, adrPageTable=@adrPageTable, adrObject=@adrPageTable[:adrObject])
    #flDropNonAlphas = true # should in fact use getPref
    flDropNonAlphas = getPref("dropnonalphas")
    #flLowerCaseFileNames = true # ditto
    flLowerCaseFileNames = getPref("lowercasefilenames")
    #maxLength = 100 # ditto
    maxLength = getPref("maxfilenamelength")
    extension = getPref("fileextension")
    n = n.to_s
    n = n.dropNonAlphas if flDropNonAlphas
    n = n.downcase if flLowerCaseFileNames
    return n[0, maxLength - extension.length]
  end
  def getSiteFolder(adrPageTable=@adrPageTable)
    return adrPageTable[:siteRootFolder] if adrPageTable[:siteRootFolder]
    adrFtpSite = adrPageTable[:ftpsite]
    folder = nil
    File.open(adrFtpSite) {|io| folder = YAML.load(io)[:folder]}
    folder = Pathname.new(folder).expand_path
    # ensure whole containing path exists; if not, use temp folder
    folder = Pathname.new(`mktemp -d /tmp/website.XXXXXX`) unless folder.dirname.exist?
    # create the folder if necessary # no, I've commented this out for now, seems unnecessary as we mkpath later
    # folder.mkdir unless folder.exist?
    # set in adrPageTable and also return it
    return (adrPageTable[:siteRootFolder] = folder)
  end
  def addPageToGlossary(adrObject, adrPageTable=@adrPageTable)
    # this is different from what Frontier does!
    # we maintain an #autoglossary on disk, loaded as :autoglossary hash
    # but we do not save out! that is the job of whoever calls us to do that eventually
    linetext = adrPageTable[:title] # skip entityization problem for now
    path = adrPageTable[:subDirectoryPath] + adrPageTable[:fname]
    adr = adrObject
    changed = adrPageTable[:autoglossary][linetext] && (adrPageTable[:autoglossary][linetext][:adr] != adr)
    puts "#{adr} changed position from #{adrPageTable[:autoglossary][linetext][:adr]}" if changed
    # ready to store
    # unlike Frontier, we make two entries (pointing to same object) keyed by title and by simple filename
    h = Hash.new
    h[:linetext] = linetext
    h[:path] = path
    h[:adr] = adr
    # calculate url if there is a base url in #ftpsite
    begin
      url = (File::open(adrPageTable[:ftpsite].to_s) {|io| YAML::load(io)})[:url]
      url += "/" unless url =~ %r{/$}
      uri = URI::join(url, URI::escape(path.to_s))
      h[:url] = uri.to_s
    rescue
    end
    adrPageTable[:autoglossary][adrPageTable[:f].simplename.to_s] = h
    adrPageTable[:autoglossary][linetext] = h if linetext
  end
  def processMacros(s, theBinding, adrPageTable=@adrPageTable)
    # process macros; the Ruby equivalent is to use ERB, so we do
    # we should also be handling autoparagraphs and activeURLs and isoFilter subs and quoted-text glossary subs
    # but I'm not ready yet
    # see html.data.processMacrosCallback for more about how this used to work
    # the real work is done in the BindingMaker class, q.v.
    # first put adrPageTable where utilities can see it
    # @adrPageTable = adrPageTable
    # now do the macros
    #return ERB.new(s).result(BindingMaker.new(self).getBinding)
    # b = BindingMaker.new(self)
    # load all tools into BindingMaker instance as sandbox
    # adrPageTable["tools"].each { |k,v| b.instance_eval(File.read(v)) }
    return ERB.new(s).result(theBinding)
  end
  def refGlossary(name, adrPageTable=@adrPageTable)
    # return a complete <a> tag referring to the named target from where we are, or nil
    # Frontier merely substitutes a glossPath at this stage, but I don't see the need for that
    # as usual I am leaving out a LOT of Frontier's logic here, just to get the base case written
    # also I'm departing from Frontier's logic: we have two hashes to look in:
    # "glossary" is user glossary of name-substitution pairs
    # :autoglossary is our glossary of hashes pointing to pages we have built
    # must look in both
    # new (non-Frontier) logic: if name contains #, split into name and anchor, search, reassemble
    name, anchor = name.split("#")
    if anchor.nil?
      anchor = ""
    else
      anchor = "#" + anchor
    end
    g = adrPageTable[:autoglossary] # try autoglossary
    if g && g[name] && g[name][:path]
      path = g[name][:path] # relative pathname to target
      path = adrPageTable[:siteRootFolder] + path # now it's absolute, matching :f, ready to form link
      return %{<a href="#{path.relative_uri_from(adrPageTable[:f])}#{anchor}">} 
    end
    g = adrPageTable["glossary"] # try user glossary
    if g && g[name]
      return %{<a href="#{g[name]}#{anchor}">}
    end
    puts "RefGlossary failed on #{name}, apparently while processing #{adrPageTable[:adrObject]}"
    return nil
  end
  def getOneDirective(directiveName, adrObject)
    # simple-mindedly pull a directive out of a page's contents
    d = Hash.new
    if adrObject.extname == ".txt"
      runDirectives(adrObject, d)
    elsif adrObject.extname == ".opml"
      runOutlineDirectives(adrObject, d)
    end
    return d[directiveName] # value or nil
  end
  def getTitleAndPath(id, adrPageTable=@adrPageTable)
    # grab title (linetext) and path from autoglossary
    return [nil,nil] unless adrPageTable[:autoglossary] && adrPageTable[:autoglossary][id]
    return [adrPageTable[:autoglossary][id][:linetext], adrPageTable[:autoglossary][id][:path]]
  end
  def getNextPrev(obj, adrPageTable=@adrPageTable)
    # return array of two identfiers, namely the prev and next renderable page at this level
    # ids suitable for use in autoglossary consultation
    # if there is a #nextprevs, we just use that
    # otherwise we use the physical file system
    # either or both element of the array can be nil to signify none
    result = [nil, nil]
=begin
    npt = obj.dirname + "#nextprevs"
    if npt.exist?
      #  not yet written
      raise "error, nextprevs routine not yet written"
    else
      # just use alphabetical order
      sibs = obj.dirname.children.delete_if do |p|
        p.basename.to_s =~ /^[#.]/ || p.extname != ".txt"
      end
      us = sibs.index(obj)
      s = ""
      if us > 0
        result[0] = sibs[us-1].simplename.to_s
      end
      if us < sibs.length - 1
        result[1] = sibs[us+1].simplename.to_s
      end
      return result
    end
=end
    sibs = pagesInFolder(obj.dirname)
    id = obj.simplename.to_s
    us = sibs.index(id)
    result[0] = sibs[us-1] if us > 0
    result[1] = sibs[us+1] if us < sibs.length - 1
    return result
  end
  def pagesInFolder(folder, adrPageTable=@adrPageTable)
    # return array of identifiers of renderable pages in folder
    # these identifiers are suitable for use in getTitleAndPath and other autoglossary consultation
    # if there is a #nextprevs, the array is ordered as in the nextprevs
    # otherwise we just use alphabetical order (filesystem)
    # return nil if no result
    arr = Array.new
    nextprevs = folder + "#nextprevs.txt"
    if (nextprevs.exist?)
      File.open(nextprevs) do |io|
        io.each do |id|
          arr << id.chomp
        end
      end
    else
      # if not, just use alphabetical order
      # TODO, need to regularise how we decide if something is a page
      # we are doing this in different places
      folder.children.each do |p|
        next if p.basename.to_s =~ /^[#.]/
        arr << p.simplename.to_s if [".txt", ".opml"].include?(p.extname)
      end
    end
    return (arr.length > 0 ? arr : nil)
  end
  def getSubs(obj, adrPageTable=@adrPageTable)
    # return array of identifiers of renderable pages in the "downfolder" from obj
    downfolder = obj.dirname + (obj.simplename.to_s + "folder")
    return nil unless (downfolder.directory?)
    return pagesInFolder(downfolder)
  end
  def getImageData(imageSpec, adrPageTable=@adrPageTable)
    # Frontier has fu for seeking the image, but I will assume an "images" folder for now
    raise "No 'images' folder found" unless adrPageTable["images"]
    imagePath = nil
    adrPageTable["images"].children.each do |im|
      if im.simplename.to_s == imageSpec
        imagePath = im; break
      end
    end
    raise "Image #{imageSpec} not found" unless imagePath
    imagesFolder = adrPageTable[:siteRootFolder] + "images" # should be a pref
    # actually write the image; I've always thought this is an inappropriate place to do this...
    # ... and would eventually like to change it
    imagesFolder.mkpath
    imageTarg = imagesFolder + imagePath.basename
    FileUtils.cp(imagePath, imageTarg, :preserve => true) if imageTarg.needs_update_from(imagePath)
    # determine image dimensions
    width, height = imageTarg.image_size
    # construct and return image data table
    url = imageTarg.relative_uri_from(adrPageTable[:f])
    return {:width => width, :height => height, :path => imageTarg, :adrImage => imagePath, :url => url}
  end
  def getPref(s, adrPageTable=@adrPageTable)
    # look for pref value
    # first try page table
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
    else
      true
    end
  end
  def saveOutAutoglossary(g=nil, adrPageTable=@adrPageTable)
    g ||= adrPageTable[:autoglossary]
    if g
      File.open(adrPageTable[:adrSiteRootTable] + "#autoglossary.yaml", "w") do |io| 
        YAML.dump(g, io)
      end
    end
  end
end

if __FILE__ == $0
  
# UserLand::Html::releaseRenderedPage("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/fourwindowsfolder/adbk.txt")
# UserLand::Html::preflightSite("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/appmodes.txt")
# UserLand::Html::releaseRenderedPage("./scriptde.txt")
# UserLand::Html::preflightSite(Pathname.new("./scriptde.txt").expand_path)
# UserLand::Html::publishSite("/Users/mattleopard/anger/Word Process/jobs/dialectic/docs/appmodes.txt")
# UserLand::Html::releaseRenderedPage("./scriptdefolder/develop.txt")
pp UserLand::Html::everyPageOfSite(Pathname.new("/Volumes/gromit/Users/matt2/anger/Word Process/web sites/emperorWebSite/site/default2.opml").expand_path)
#UserLand::Html::newSite()
#UserLand::Html::releaseRenderedPage("/Volumes/gromit/Users/matt2/anger/Word Process/emperorWebSite/site/default2.opml")
#require 'profiler'
#Profiler__::start_profile
#UserLand::Html::releaseRenderedPage("/Volumes/gromit/Users/matt2/anger/Word Process/web sites/emperorWebSite/site/default2.opml")
#Profiler__::print_profile($stdout)


end
