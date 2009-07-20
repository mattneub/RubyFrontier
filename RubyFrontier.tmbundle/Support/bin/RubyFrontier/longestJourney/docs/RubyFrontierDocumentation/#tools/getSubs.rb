def getSubs(obj)
  # return array of identifiers of renderable pages in the "downfolder" from obj
  # useful structuring a site this way
  downfolder = obj.dirname + (obj.simplename.to_s + "folder")
  return nil unless (downfolder.directory?)
  return html.pagesInFolder(downfolder)
end