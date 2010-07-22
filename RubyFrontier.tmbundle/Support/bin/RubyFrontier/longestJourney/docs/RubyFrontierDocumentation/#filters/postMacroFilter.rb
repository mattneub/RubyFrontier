def postMacroFilter(adrPageTable)
  # adrPageTable[:postmacrotext] = process(adrPageTable[:postmacrotext])
  if adrPageTable[:kramdown]
    adrPageTable[:postmacrotext] = Kramdown::Document.new(
      adrPageTable[:postmacrotext], :auto_ids => false, :entity_output => :numeric
    ).to_html.gsub("&quot;", '"')
  end
end