def finalFilter(adrPageTable)
  # adrPageTable[:renderedtext] = process(adrPageTable[:renderedtext])
  
  # I am generating some self-referential links, fix those
  adrPageTable[:renderedtext] = adrPageTable[:renderedtext].gsub(/<a href="">(.*?)<\/a>/, '\1')
  
end 
