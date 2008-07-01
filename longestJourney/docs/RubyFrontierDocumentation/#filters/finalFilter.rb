def finalFilter(adrPageTable)
  # adrPageTable[:renderedtext] = process(adrPageTable[:renderedtext])
  # for example, here's how to get smartypants support:
  
  if adrPageTable[:markdown] || adrPageTable[:smartypants]
    IO.popen(ENV['TM_SUPPORT_PATH'] + "/bin/SmartyPants.pl", "r+") do |io|
      io.write adrPageTable[:renderedtext]
      io.close_write
      adrPageTable[:renderedtext] = io.read
    end
    # another problem: due to a bug in Markdown (I think), can generate <p><pre>
    adrPageTable[:renderedtext] = adrPageTable[:renderedtext].gsub("<p><pre>", "<pre>").gsub("</pre></p>", "</pre>")
    # also can generate <p>...<div>
    adrPageTable[:renderedtext] = adrPageTable[:renderedtext].gsub(%r{<p>\s*?<div}, "<div").gsub(%r{</div>\s*?</p>}, "</div>")
    adrPageTable[:renderedtext] = adrPageTable[:renderedtext].gsub(%r{(<div.*?>)</p>}, '\1').gsub(%r{<p></div>}, "</div>")
    # also because of snippets I am generating some self-referential links, fix those
    adrPageTable[:renderedtext] = adrPageTable[:renderedtext].gsub(/<a href="">(.*?)<\/a>/, '\1')
  end
  
end
