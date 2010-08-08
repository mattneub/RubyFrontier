def nextprevlinks()
  p, n = html.getNextPrev(adrObject)
  ntitle, npath = html.getTitleAndPath(n) if n
  ptitle, ppath = html.getTitleAndPath(p) if p
  s = ""
  s << "Prev: " + html.getLink(ptitle, ppath) if p
  s << " | " if p and n
  s << "Next: " + html.getLink(ntitle, npath) if n
  "<p>#{s}</p>\n"
end