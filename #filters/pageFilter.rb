#!/usr/bin/env ruby
#
#  Created by matt neuburg on 2008-01-14.
#  Copyright (c) 2008. All rights reserved.

def pageFilter(adrPageTable)
  if adrPageTable[:markdown]
    IO.popen(ENV['TM_SUPPORT_PATH'] + "/bin/markdown.pl", "r+") do |io|
      io.write adrPageTable[:bodytext]
      io.close_write
      adrPageTable[:bodytext] = io.read
    end
    # cool, but markdown substitutes &lt;% for <%, so if we have macros they've just been stripped
    adrPageTable[:bodytext] = adrPageTable[:bodytext].gsub("&lt;%", "<%")
  end
  if !adrPageTable[:metadescription]
    adrPageTable[:metadescription] = makeDescription(adrPageTable[:bodytext])
  end     
end

def makeDescription(s)
  r = s.match /<p[^>]*?>(.*?)<\/p>/mi
  if r.nil?
     return "(No description available)" 
  end
  t = r[1]
  t = t.gsub(/[\r\n\t]/, " ").squeeze(" ").strip
  t = t.gsub(/<.*?>/, "")
  # omitting glosssub fix for now
  # problem of quotation marks not really solved
  t = t.gsub(/"/, "&quot;")
  t = t.gsub(/\\/, "")
  # extract the first sentence if possible
  r = t.match /^(.*?\.)/mi
  r && (t = r[1])
  if t.length > 150
    t = t[0,150]
    t = t[0..t.rindex(" ")] + "..."
  end
  return t
end