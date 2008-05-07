def finalFilter(adrPageTable)
  # adrPageTable[:renderedtext] = process(adrPageTable[:renderedtext])
  # for example, here's how to get smartypants support:
  
  if adrPageTable[:markdown] || adrPageTable[:smartypants]
    IO.popen(ENV['TM_SUPPORT_PATH'] + "/bin/SmartyPants.pl", "r+") do |io|
      io.write adrPageTable[:renderedtext]
      io.close_write
      adrPageTable[:renderedtext] = io.read
    end
  end
  
end
