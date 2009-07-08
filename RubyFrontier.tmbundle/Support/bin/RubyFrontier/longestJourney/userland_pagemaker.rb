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
      puts "Rendered '#{adrPageTable[:adrObject]}'"
    else # just copy it
      if f.needs_update_from(adrPageTable[:adrObject])
        FileUtils.cp(adrPageTable[:adrObject], f, :preserve => true)
        puts "Copied '#{adrPageTable[:adrObject]}'"
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
      adrPageTable[:fname] ||= getFileName(adrPageTable[:adrobject].simplename)
    else
      adrPageTable[:fname] ||= adrPageTable[:adrobject].basename
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
      LCHash[YAML.load_file(adrGlossTable)]
    else
      LCHash.new
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
      puts "'#{adrObject}'", "changed position from #{glossary[linetext][:adr]}" if changed
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
            puts "Remote glossary lookup failed on #{href}", "apparently while processing '#{adrPageTable[:adrObject]}'"
          end
        else # non-remote-site (normal) semantics
          url = refGlossary(href.gsub('\\',''))
          puts "RefGlossary failed on #{href}", "apparently while processing '#{adrPageTable[:adrObject]}'" unless url
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
    adrObject = adrPageTable[:autoglossary][adrObject][:adr] unless adrObject.kind_of? Pathname
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
  def getTitleAndPaths(id, adrPageTable=@adrPageTable)
    # grab title (linetext) and paths from autoglossary; useful for macros
    return [nil,nil,nil] unless adrPageTable[:autoglossary] && (entry = adrPageTable[:autoglossary][id])
    return entry[:linetext], entry[:path], entry[:adr]
  end
  def getTitleAndPath(id, adrPageTable=@adrPageTable)
    getTitleAndPaths(id, adrPageTable) # we are legacy
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
    # TODO: I also assume single images folder at top level (but I leave folder name as a pref)
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
      File.open(f, "w") { |io| YAML.dump(Hash[g], io) }
    end
  end
end