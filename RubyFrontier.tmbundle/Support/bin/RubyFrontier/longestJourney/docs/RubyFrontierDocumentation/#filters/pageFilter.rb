def pageFilter(adrPageTable)
  # support for haml-based template
  if adrPageTable[:haml] and (t = adrPageTable.fetch2(:template)) and t.kind_of?(Pathname)
    adrPageTable[:directTemplate] = Haml::Template.new(t).render
  end
end