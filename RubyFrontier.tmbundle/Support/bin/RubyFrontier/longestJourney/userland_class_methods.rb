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
    # NEW FEATURE: look for #user.rb at top level of site and require (load) it if found
    # in a way this might replace the old callFileWriterStartup mechanism
    userrb = self.getFtpSiteFile(adrObject).dirname + "#user.rb"
    if userrb.exist? && !$localuserrbloaded
      $localuserrbloaded = true
      require userrb.to_s 
    end
    
    pm = PageMaker.new
    pm.buildObject(adrObject)
    puts "page built in #{Time.new.to_f - time} seconds" if doTimings
    pm.writeFile
    
    # TODO: omitting file writer shutdown mechanism
    # callFileWriterShutdown(adrObject, adrStorage)
    
    pm.saveOutAutoglossary # save out autoglossary if any
        
    if flPreview && (File.extname(pm.adrPageTable[:fname]).downcase.start_with?(".htm")) # supposed to be a test for browser displayability
      if (apacheURL = pm.adrPageTable[:ftpsite][:apacheURL])
        f = pm.adrPageTable[:f].relative_path_from(Pathname(pm.adrPageTable[:ftpsite][:apacheSite]).expand_path)
        `open #{URI.escape(apacheURL + f)}`
      else
        `open file://#{URI.escape(pm.adrPageTable[:f].to_s)}`
      end
    end
    
  end
  def self.publishSite(adrObject, preflight = true, flPreview = true)
    adrObject = Pathname(adrObject).expand_path
    self.guaranteePageOfSite(adrObject) # raises if not
    puts "publishing site"
    self.preflightSite(adrObject) if preflight
    self.everyPageOfSite(adrObject).each do |p|
      puts " "
      puts "publishing '#{p}'"
      self.releaseRenderedPage(p, (p == adrObject) && flPreview) # the only one to open in browser is the one we started with
    end
    puts " "
    puts "finished publishing site"
  end
  def self.publishFolder(adrObject, preflight=true)
    adrObject = Pathname(adrObject).expand_path
    self.guaranteePageOfSite(adrObject) # raises if not
    puts "publishing folder #{adrObject.dirname.basename}"
    self.preflightSite(adrObject) if preflight
    self.everyPageOfFolder(adrObject.dirname).each do |p|
      puts "publishing '#{p}'"
      self.releaseRenderedPage(p, (p == adrObject)) # the only one to open in browser is the one we started with
    end
    puts "finished publishing folder #{adrObject.dirname.basename}"
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
      Find.prune if p.basename.to_s.start_with?("#", ".")
      result << p if (!p.directory? && p.simplename != "") # ignore invisibles
    end
    result
  end
  class << self; memoize :everyPageOfFolder; end # have to talk this way yadda yadda
  def self.everyPageOfSite(adrObject)
    self.everyPageOfFolder(self.getFtpSiteFile(adrObject).dirname)
  end
  def self.preflightSite(adrObject)
    puts "preflighting site..."
    # prebuild autoglossary using every page of table containing adrObject path
    glossary = LCHash.new
    pm = nil # so that we have a PageMaker object left over at the end
    self.everyPageOfSite(Pathname(adrObject)).each do |p|
      # can be slow, so provide feedback while we work
      print "."
      pm = PageMaker.new
      pm.memoize = false # so if we then publishSite, existing values won't bite us
      pm.buildPageTableFully(p)
      tempGlossary = LCHash.new
      pm.addPageToGlossary(p, tempGlossary) # downcases for us
      glossary.merge!(tempGlossary) do |k, vold, vnew| # notify user of non-uniques
        puts " "
        puts "----", "Non-unique autoglossary entry detected for #{k}",
          vold.inspect, "vs.", vnew.inspect, "while processing '#{p}'" if vold != vnew
        vnew
      end
    end
    pm.saveOutAutoglossary(Hash[glossary]) # save out resulting autoglossary
    puts " "
    puts "site preflighted, autoglossary rebuilt and saved"
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
  def self.newSite(testing = false)
    s = ""
    if !testing
      s = `"#{ENV['TM_SUPPORT_PATH']}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog" filesave --title "New Web Site" --text "Specify a folder to create"`
    else # testing, use with care
      s = Pathname("~/Desktop/testingXYZ").expand_path.to_s
    end
    exit if s == "" # user cancelled
    p = Pathname(s.chomp)
    p.mkpath
    FileUtils.cp_r($newsite.to_s + '/.', p)
    FileUtils.rm((p + "#autoglossary.yaml").to_s) # just causes errors if it's there
    # also get rid of svn leftovers if present
    `find '#{p}' -name ".svn" -print0 | xargs -0 rm -R -f`
    # and get rid of .DS_Store if present
    `find '#{p}' -name ".DS_Store" -print0 | xargs -0 rm -R -f`
    `"#{ENV['TM_SUPPORT_PATH']}/bin/mate" '#{p}'` unless testing
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
  def self.test_output
    s = <<END
this is a test
and this is a test
END
    puts s
  end
  def self.test_raise
    raise "oops"
  end
end
