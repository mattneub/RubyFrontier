require 'enumerator'

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
