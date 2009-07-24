def finalFilter(adrPageTable)
  # adrPageTable[:renderedtext] = process(adrPageTable[:renderedtext])
  # for example, here's how to get smartypants support:
  require ENV['TM_SUPPORT_PATH'] + "/lib/escape.rb"
  if adrPageTable[:markdown] || adrPageTable[:smartypants]
    IO.popen(e_sh(ENV['TM_SUPPORT_PATH']) + "/bin/SmartyPants.pl", "r+") do |io|
      io.write adrPageTable[:renderedtext]
      io.close_write
      adrPageTable[:renderedtext] = io.read
    end
  end
  
end
