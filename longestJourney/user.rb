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
end

module User
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
END
    h = Hash.new
    s.split("\n").each_slice(2) {|a| h[a[0]] = a[1]}
    return h
  end
end
module User::Renderers
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
