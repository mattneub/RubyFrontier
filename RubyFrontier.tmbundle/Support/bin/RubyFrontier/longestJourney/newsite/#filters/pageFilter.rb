def pageFilter(adrPageTable)
  # adrPageTable[:bodytext] = process(adrPageTable[:bodytext])
  # for example, here's how to get markdown support:

  if adrPageTable[:markdown]
    IO.popen(%{"#{ENV['TM_SUPPORT_PATH']}/bin/markdown.pl"}, "r+") do |io|
      io.write adrPageTable[:bodytext]
      io.close_write
      adrPageTable[:bodytext] = io.read
    end
    # cool, but markdown substitutes &lt;% for <%, so if we have macros they've just been stripped
    adrPageTable[:bodytext] = adrPageTable[:bodytext].gsub("&lt;%", "<%")
  end
  
end