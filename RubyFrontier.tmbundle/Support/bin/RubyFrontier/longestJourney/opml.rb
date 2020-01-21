=begin
Simulate some Frontier op.* verbs using OPML as the outline source.
=end

# superclass's "new" factory method lets us substitute different subclass implementations at will
# also container for methods that don't vary between implementations
# this is unnecessary as there is now only implementation, namely Nokogiri, but whatever

class Opml

  MAXINT = 1 << 64
  
  def self.new(*args)
    object = Opmlnokogiri.allocate
    object.send :initialize, *args
    object
  end
    
  def firstsummit()
    go(:left,MAXINT)
    go(:up,MAXINT)
  end
  
  def level() 
    cur = @curline
    l = 1
    l += 1 while go(:left)
    @curline = cur
    return l
  end
  
=begin  # "go" semantics in Frontier are odd: 
  # the rule is, return true if you can go the given direction at all, even if not the given number
  # to make it easy to conform to this rule, and to reduce "go" to minimal indivisibles,
  # we express it through a dispatcher-wrapper architecture:
  # our "go" simply calls "go_wrapper" with the desired direction,
  # and "go_wrapper" takes care of returning the right thing
  # NB use of "call" lets us use "return" and does not seem slower than "yield" and a proc
  # it is up to our subclasses to implement methods godownone, goupone, goleftone, gorightone
  # goflatdownone and goflatupone are implemented in terms of those, so we implement them here
=end
  def go_wrapper(count, meth)
    return false unless meth.call
    (count-1).times {break unless meth.call}
    return true
  end
  
  def go(dir, count=1)
    count = MAXINT if count == :infinity
    return go_wrapper(count, self.method("go#{dir.to_s}one".to_sym))
  end
  
  def goflatdownone()
    return true if (go(:right) || go(:down))
    # no? okay, seek a left that has a down
    curline = @curline # mark our place in case we have to unwind
    while true
      unless go(:left)
        @curline = curline # failed, unwind
        return false
      end
      return true if go(:down)
    end
    result
  end
  
  def goflatupone()
    if go(:up)
      return true unless hasSubs
      while true
        go(:right)
        go(:down, MAXINT)
        return true unless hasSubs
      end
    end
    return true if go(:left)
    return false
  end
  private :go_wrapper, :goflatdownone, :goflatupone
  
  def inspect_visit(s,lev)
    while true
      s << "  " * lev + getLineText + "\n"
      if go(:right)
        inspect_visit(s,lev+1)
        go(:left)
      end
      return unless go(:down)
    end
  end
  private :inspect_visit
  def inspect(io = nil) # io can be anything that accepts << (stream, string, whatever), or we'll hand you a string
    old_curline = @curline
    io_nil = io.nil?
    s = (io_nil ? "" : io)
    inspect_visit(s,0)
    @curline = old_curline
    return (io_nil ? s : nil)
  end
  def inspect_flat()
    old_curline = @curline
    firstsummit
    s = getLineText + "\n"
    while go(:flatdown)
      s << getLineText << "\n"
    end
    @curline = old_curline
    s
  end
  def inspect_raw()
    @top.to_a
  end
  def getLineTextRaw
    @curline
  end
  
  # class method, utility: translate line-indented text to OPML
  # at the moment we basically assume line-indent by spaces (probably two spaces per level)
  
  def self.doThisLevel(lines, level, doc, curnode) # private loop/recurse helper for next method
    # lines is the array of lines
    # level is the level we are at:
    # a deeper level means add a child, another at this level means add a sibling
    # doc is a reference to the xml document
    # curnode points to an already processed node; level is its level
    # =======
    # keep processing lines as long as level doesn't go shallower
    # if it does, do nothing and let unwinding of recursion deal with it
    while (lines.length > 0) && ((nextlevel = lines[0][:level]) >= level)
      if nextlevel > level
        newnode = curnode.add_child(Nokogiri::XML::Node.new("outline", doc))
        newnode['text'] = lines[0][:text]
        lines.shift
        doThisLevel(lines, nextlevel, doc, newnode) # dive dive dive
      else
        newnode = curnode.add_next_sibling(Nokogiri::XML::Node.new("outline", doc))
        newnode['text'] = lines[0][:text]
        curnode = newnode
        lines.shift
      end
    end
  end
  class << self; private :doThisLevel; end
  def self.textToOpml(s)
    doc = Nokogiri::XML::Document.new
    doc.root = Nokogiri::XML::Node.new("opml", doc)
    doc.root['version'] = '1.0'
    body = doc.root.add_child(Nokogiri::XML::Node.new("body", doc))
    lines = s.split("\n")
    # separate level from content up front
    lines = lines.map do |line|
        line =~ /^(\s*)/
        level = $1.length
        rest = line[level..-1]
        {:text => rest, :level => level}
    end
    doThisLevel(lines, -1, doc, body)
    doc
  end
  
end

class Opmlnokogiri < Opml
  myrequire 'nokogiri'
  # ivars: doc, top, curline
  def initialize(f) # f can be pathname or string
    @doc = Nokogiri::XML::Document.parse(f, &:noblanks) # Nokogiri handles both
    @top = @doc.search("body").first
    self.firstSummit()
  end
  def firstSummit
    @curline = @top.first_element_child
  end
  def getLineText
    @curline["text"] || ""
  end
  def setLineText(s)
    @curline["text"] = s
  end
  def countSubs
    @curline.elements.length
  end
  def hasSubs
    @curline.element.length > 0
  end
  def gorightone()
    righty = @curline.first_element_child
    if righty
      @curline = righty
      return true
    else
      return false
    end
  end
  def godownone()
    sib = @curline.next_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  def goupone()
    sib = @curline.previous_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  def goleftone()
    parent = @curline.parent
    if parent == @top
      return false
    else
      @curline = parent
      return true
    end
  end
  
  def insert(s, dir)
    el = Nokogiri::XML::Node.new('outline', @doc)
    case dir
    when :down
      @curline.next = el
    when :right
      @curline.prepend_child(el)
    end
    @curline = el # select inserted line
    setLineText(s) # pass thru setLineText as bottleneck so entityization is uniform
  end
  def deleteLine()
    # if we have previous sibling, select it
    # if not, but we have following sibling, select it
    # if not, but we have parent (we are not at top), select it
    # if not, we must be the only line; replace it by an empty-text line
    line_to_delete = @curline
    return line_to_delete.remove if (go(:up,1) || go(:down,1) || go(:left,1))
    el = Nokogiri::XML::Element.new('outline', @doc)
    el['text'] = ""
    @curline.parent.children = el
    @curline = el
  end
end

# withdraw use of REXML, Nokogiri is cleaner
=begin
class Opmlrexml < Opml
  myrequire ['rexml/document', :REXML]
  
  # ivars: doc, top, curline
  def initialize(f) # f can be pathname or string
    @doc = f.kind_of?(Pathname) ? Document.new(File.read(f)) : Document.new(f)
    @top = @doc.root.elements["body"]
    self.firstSummit()
  end
  def write(io, indent=1, transitive = false, hack = false)
    @doc.write(io, indent, transitive, hack)
  end
  def firstSummit
    @curline = @top.elements[1]
  end
  def getLineText
    # translate the characters <, >, &, ', and " from '&lt;', '&gt;', '&amp', '&apos', and '&quot' 
    #Text.unnormalize(@curline.attributes["text"])
    return @curline.attributes["text"] || ""
  rescue
    return ""
  end
  def setLineText(s)
    #@curline.attributes["text"] = Text.normalize(s)
    @curline.attributes["text"] = s
    # NB there was an REXML 3.1.4 bug where & in &amp; is not entityized
    # I worked around this by saying:
    # ... = s.gsub("&amp;", "&amp;amp;")
    # However, fixed this by updating REXML to current (presently 3.1.7.3)
  end
  def countSubs
    @curline.elements.size
  end
  def hasSubs
    @curline.has_elements?
  end
  def insert(s, dir)
    el = Element.new('outline')
    case dir
    when :down
      @curline.parent.insert_after(@curline, el)
    when :right
      first = @curline[0]
      if first
        @curline.insert_before(first, el)
      else
        @curline.add(el)
      end
    end
    @curline = el # select inserted line
    setLineText(s) # pass thru setLineText as bottleneck so entityization is uniform
  end
  
  def godownone()
    sib = @curline.next_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  
  def goupone()
    sib = @curline.previous_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  
  def gorightone()
    righty = @curline.elements[1]
    if righty
      @curline = righty
      return true
    else
      return false
    end
  end
    
  def goleftone()
    parent = @curline.parent
    if parent == @top
      return false
    else
      @curline = parent
      return true
    end
  end
  private :godownone, :goupone, :gorightone, :goleftone
  
  def deleteLine()
    # if we have previous sibling, select it
    # if not, but we have following sibling, select it
    # if not, but we have parent (we are not at top), select it
    # if not, we must be the only line; replace it by an empty-text line
    line_to_delete = @curline
    return line_to_delete.remove if (go(:up,1) || go(:down,1) || go(:left,1))
    el = Element.new('outline')
    el.add_attribute('text',"")
    @curline.parent.elements[1] = el
    @curline = el
  end
end
=end

# withdraw use of libxml entirely, as it is too difficult for most people to install these days
=begin
class Opmllibxml < Opml
  myrequire ['xml/libxml', :XML]
  if defined?(XML)
    class XML::Node
      def next_element
        ptr = self.next
        while ptr
          return ptr if ptr.element?
          ptr = ptr.next
        end
        return nil
      end
      def previous_element
        ptr = self.prev
        while ptr
          return ptr if ptr.element?
          ptr = ptr.prev
        end
        return nil
      end
    end
  end
    
  # ivars: doc, top, curline
  def initialize(f) # f can be pathname or string
    @doc = f.kind_of?(Pathname) ? Document.file(f) : Document.string(f)
    @top = @doc.root.find_first("body")
    self.firstSummit()
  end
  def write(io, indent=1, transitive = false, hack = false)
    @doc.write(io, indent, transitive, hack)
  end
  def firstSummit 
    @curline = @top.find_first("outline[1]")
  end
  def getLineText
    @curline["text"] || ""
  rescue
    ""
  end
  def setLineText(s)
    @curline["text"] = s
  end
  def countSubs
    @curline.find("child::*").length
  end
  def hasSubs
    @curline.find_first("child::*[1]")
  end
  def insert(s, dir) #done
    el = Node.new('outline')
    case dir
    when :down
      @curline.next = el
    when :right
      first = @curline.find_first("outline[1]")
      if first
        first.prev = el
      else
        # @curline.child = el # "deprecated"
        @curline << el
      end
    end
    @curline = el # select inserted line
    setLineText(s) # pass thru setLineText as bottleneck so entityization is uniform
  end
  
  def godownone()
    #sib = @curline.find_first("following-sibling::outline[1]")
    sib = @curline.next_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  def goupone()
    #sib = @curline.find_first("preceding-sibling::outline[1]")
    sib = @curline.previous_element
    if sib
      @curline = sib
      return true
    else
      return false
    end
  end
  def gorightone()
    righty = @curline.find_first("outline[1]")
    if righty
      @curline = righty
      return true
    else
      return false
    end
  end
  def goleftone()
    parent = @curline.parent
    #if parent == @top
    #if parent.name == "body"
    if parent.equal?(@top)
      return false
    else
      @curline = parent
      return true
    end
  end

  def deleteLine() #done?
    # if we have previous sibling, select it
    # if not, but we have following sibling, select it
    # if not, but we have parent (we are not at top), select it
    # if not, we must be the only line; replace it by an empty-text line
    parent = @curline.parent
    line_to_delete = @curline
    return line_to_delete.remove! if (go(:up,1) || go(:down,1) || go(:left,1))
    @curline.remove!
    parent << el = Node.new('outline')
    el['text'] = ""
    @curline = el
  end
  
  def inspect_flat()
    s = ""
    @top.find("descendant::*").to_a.each {|node| s << (node["text"] || "") << "\n"}
    s
  end
  
end
=end

