def breadCrumbs()
  s = @adrPageTable[:title]
  nomad = @adrPageTable[:adrObject]
  while true
    nomad = nomad.dirname
    if nomad == @adrPageTable[:adrSiteRootTable]
      s = "Help > " + s
      break
    end
    if nomad.to_s =~ /folder$/i
      id = nomad.basename.to_s[0..-7]
      title, path = html.getTitleAndPath(id, @adrPageTable)
      s = %{#{html.refGlossary(id, @adrPageTable)}#{title}</a>} + " > " + s
    end
  end
  #title, path = html.getTitleAndPath("scriptde", @adrPageTable)
  #{}"title is '#{title}', path is '#{path}'"
  return s
end