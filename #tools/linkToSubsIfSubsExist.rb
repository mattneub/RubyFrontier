def linkToSubsIfSubsExist
  obj = @adrPageTable[:adrObject]
  downfolder = obj.dirname + (obj.simplename.to_s + "folder")
  return "" unless (downfolder.directory?)
  puts downfolder
  # rest not yet written
  # return "<p>error, linkToSubs routine not yet written</p>"
  nextprevs = downfolder + "#nextprevs.txt"
  return "" unless (nextprevs.exist?)
  s = "<ul>"
  File.open(nextprevs) do |io|
    io.each do |id|
      id.chomp!
      title, path = html.getTitleAndPath(id, @adrPageTable)
      s += %{<li>#{html.refGlossary(id, @adrPageTable)}#{title}</a>} + "</li>\n"
    end
  end
  return s + "</ul>"
end