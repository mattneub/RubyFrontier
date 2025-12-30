def cssFilter(adrPageTable)
  # support for Sass
  # for this site it's easy: there's only one stylesheet and it's Sass (SCSS)
  adrPageTable[:csstext] = Sass.compile_string(adrPageTable[:csstext]).css
end
