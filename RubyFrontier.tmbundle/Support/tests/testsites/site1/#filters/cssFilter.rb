def cssFilter(adrPageTable)
  # support for Sass
  if (adrPageTable[:sheetName] == "s2") # this is our only Sass stylesheet; of course you could use some other means of identification
    adrPageTable[:csstext] = Sass.compile_string(adrPageTable[:csstext]).css
  end
end