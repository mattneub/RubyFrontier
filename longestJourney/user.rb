require 'enumerator'

module UserLand
end

module UserLand::Html
  def self.checkNextPrevs(adrObject)
    # crude but effective check that nextprevs lists are valid
    # get list of all pages; for each...
    # if there is a next prevs list in the same folder, make sure it contains a way of getting at this page
    # also make sure everything in it is in the same folder
    # obviously this is only useful if that's how we've set up nextprevs, but I have not thought thru implications
    adrObject = Pathname.new(adrObject).expand_path
    adrPageTable = Hash.new
    PageMaker.new(adrPageTable).buildPageTable(adrObject)
    raise "No autoglossary table found, cannot proceed" unless adrPageTable["autoglossary"]
    glossary = File.open(adrPageTable["autoglossary"]) {|io| YAML.load(io)}

    self.everyPageOfSite(adrObject).each do |p|
      folder = p.dirname
      nextprevs = folder + "#nextprevs.txt"
      sibs = folder.children.delete_if {|p| p.directory? || p.simplename.to_s =~ /^[#\.]/}
      if (nextprevs.exist?)
        IO.readlines(nextprevs).each do |id|
          id.chomp!
          puts "doing #{id}"
          p2 = glossary[id][:adr] rescue raise("choked on #{id}")
          puts "page #{id} not in same folder as page #{adrObject}" unless folder == p2.dirname
          sibs = sibs.delete_if {|x| x == p2}
        end
        p sibs if sibs.length > 0
      end
    end
  end
  
  # stuff for blogging
  HEARTREGEX = /<!\-\- bodytextstart \-\->(.*)<!\-\- bodytextend \-\->/m
  def self.heartOfRenderedPage(adrObject, regex = HEARTREGEX)
    # render a page and pluck out its heart; good for embedding one page in another (as in a blog)
    # regex should be like above, so that match[1] fetches desired heart
    # okay, but now I no longer use regex, since I realized all I want is the bodytext
    pm = PageMaker.new
    pm.adrPageTable[:stopAfterPageFilter] = true
    pm.buildObject(adrObject)
    # regex.match(pm.adrPageTable[:renderedtext])[1]
    pm.adrPageTable[:bodytext]
    # but I expect I will need to modify this to look for some "snip" comment or something, and snip there
  end
  class << self; memoize :heartOfRenderedPage; end # have to talk this way yadda yadda
  
end

class UserLand::Html::PageMaker
  def getSubs(obj, adrPageTable=@adrPageTable)
    # return array of identifiers of renderable pages in the "downfolder" from obj
    # useful structuring a site this way
    downfolder = obj.dirname + (obj.simplename.to_s + "folder")
    return nil unless (downfolder.directory?)
    return pagesInFolder(downfolder)
  end
  
  # stuff for blogging
  def storyHashes(adrPageTable=@adrPageTable)
    # something like this, it seems to me, is needed in order to make a blogging component feasible
    # in a blog site, there are many different situations where we need fundamental info about all "stories"
    # so it makes sense to bottleneck and standardize the routine for gathering that info 
    # (and, as a secondary benefit, we can cache that info)
    # we have one requirement: there must be a pref, pathToStories, pointing from top level to the stories folder
    # any page in that folder is considered a story
    # it is also expected (but not required?) that each story contain title, category, and date directives
    # where date is in form YYYY-MM-DD HH:MM:SS
    
    # find all stories = pages in stories folder as instructed by prefs
    arr = UserLand::Html.everyPageOfFolder(adrPageTable[:adrsiteroottable] + adrPageTable[:pathToStories])
    # create mighty array of hashes of info about those pages
    mighty = Array.new
    arr.each do |p|
      h = Hash.new
      h[:pathname] = p
      h[:category], h[:title], date = getOneDirective([:category, :title, :date], p)
      h[:date] = DateTime.strptime(date, "%F %T")
      mighty << h
    end
    return mighty
  end
  # and should memoize
end

module UserLand::User
  def self.glossary
    s = <<END
Frontier
http://frontier.userland.com
thebookontheweb
http://pages.sbcglobal.net/mattneub/frontierDef/ch00.html
Take Control
http://www.takecontrolbooks.com
TidBITS
http://www.tidbits.com
Mac Developer Journal
http://www.macdeveloperjournal.com
REALbasic
http://www.realbasic.com
Radio UserLand
http://radio.userland.com
ORA
http://www.oreilly.com
DangerIsland
http://www.dangerisland.com
Panorama
http://www.provue.com
MacTech
http://www.mactech.com
XPlain
http://www.xplain.com
Ruby
http://www.ruby-lang.org/en/
END
    h = Hash.new
    s.split("\n").each_slice(2) {|a| h[a[0]] = a[1]}
    return h
  end
end

module UserLand::Renderers
  class Halo < SuperRenderer
    def visit(op)
      while true
        linetext = op.getLineText()
        line = linetext
        didRecurse = false
        pendingClosingTags = []
        if line =~ /^\/\// # comments start with //, just substitute blank line and skip
          op.setLineText("")
          return didRecurse unless op.go(:down,1)
          next
        end
        if @adrPageTable && @adrPageTable[:halo_shortcut]
          splitter = @adrPageTable[:halo_shortcut]
          # warning: next line might not work! needs testing... works on vertical bar, tho
          if line =~ /#{'\\' + splitter}/
            # my incredibly simple-minded way of handling the single-line shortcut: split right 
            op.setLineText($`)
            op.insert($', :right)
            op.go(:left,1)
          end
        end
        if op.go(:right,1)
          childRecursed = visit(op)
          if line =~ /</
            line.scan /<([!%\?])?\s*(\/)?\s*(\w[\w:-]*)[^>]*?(\/)?>/ do |m|
              next if m[0] # starts with <% or similar, ignore
              next if m[3] # self-closing (xml) tag, ignore
              tag = "</#{m[2]}>" # proposed closing tag
              if m[1] # this *is* a closing tag, remove from list if we added it already
                ix = pendingClosingTags.index(tag)
                pendingClosingTags.delete_at(ix) if ix
                next
              end
              # okay, it's a legit closing tag, add it to the list!
              # list grows from front, because e.g. <blockquote><p> closing tag list is </p><blockquote>
              pendingClosingTags.unshift(tag)
            end
            if pendingClosingTags.length > 0
              if childRecursed
                op.insert(pendingClosingTags.join(""), :down)
              else
                op.setLineText(op.getLineText + pendingClosingTags.join(""))
              end
            end
          end
          op.go(:left,1)
          didRecurse = true
        end
        return didRecurse unless op.go(:down,1)
      end      
    end
    def render(op)
      visit(op)
      # permit use of markdown-like <a> abbreviation
      # output flat because otherwise <pre> inherits tabs from the layout
      return op.inspect_flat.gsub(/\[(.*?)\]\((.*?)\)/, '<a href="\2">\1</a>')
    end
    #def initialize(adrPageTable = nil)
    #  @adrPageTable = adrPageTable
    #end
  end
end
