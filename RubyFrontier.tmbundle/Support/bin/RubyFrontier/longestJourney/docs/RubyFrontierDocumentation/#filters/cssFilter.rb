def cssFilter(adrPageTable)
  # support for SASS
  # for this site it's easy: there's only one stylesheet and it's SASS (SCSS)
  adrPageTable[:csstext] = Sass::Engine.new(adrPageTable[:csstext], :syntax => :scss, :style => :expanded).render
end
