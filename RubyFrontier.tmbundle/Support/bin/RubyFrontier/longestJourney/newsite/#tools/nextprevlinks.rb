def nextprevlinks()
  p, n = html.getNextPrev(adrObject)
  ntitle, npath = html.getTitleAndPaths(n) if n
  ptitle, ppath = html.getTitleAndPaths(p) if p
  rel_to_top = adrsiteroottable.relative_uri_from(adrobject)
  s = ""
  s << "Prev: " + html.getLink(ptitle, rel_to_top + ppath) if p
  s << " | " if p and n
  s << "Next: " + html.getLink(ntitle, rel_to_top + npath) if n
  "<p>#{s}</p>\n"
end