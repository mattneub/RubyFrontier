def pageFilter(adrPageTable)
  # adrPageTable[:bodytext] = process(adrPageTable[:bodytext])
  # example:
  # support for writing page as Markdown
  if adrPageTable[:markdown]
    IO.popen(%{"#{ENV['TM_SUPPORT_PATH']}/bin/Markdown.pl"}, "r+") do |io|
      io.write adrPageTable[:bodytext]
      io.close_write
      adrPageTable[:bodytext] = io.read
    end
    # but markdown substitutes &lt;% for <%, so if we have macros they've just been stripped
    adrPageTable[:bodytext] = adrPageTable[:bodytext].gsub("&lt;%", "<%")
  end
  # however, I now advise using kramdown instead of Markdown; see 'postMacroFilter.rb'
  # another example:
  # support for writing all or part of a page in Haml
  # our crude but brilliantly effective strategy: delimit in <%%% ... %%%> 
  # and switch on "embeddedhaml"
  if adrPageTable[:embeddedhaml]
    adrPageTable[:bodytext] = adrPageTable[:bodytext].gsub(/^<%%%(.*?)%%%>/m) do |s|
      Haml::Template.new{$1}.render # block returning string
    end
  end
  # still another example:
  # support for template being written as Haml
  if adrPageTable[:hamltemplate] and (t = adrPageTable.fetch2(:template))
    adrPageTable[:directTemplate] = Haml::Template.new(t).render # file
  end
end