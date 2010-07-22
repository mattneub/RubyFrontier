def firstFilter(adrPageTable)
  # support for haml-based template
  if adrPageTable[:haml] and (t = adrPageTable.fetch2(:template)) and t.kind_of?(Pathname)
    adrPageTable[:directTemplate] = Haml::Engine.new(File.read(t), :attr_wrapper => '"').render
  end
end