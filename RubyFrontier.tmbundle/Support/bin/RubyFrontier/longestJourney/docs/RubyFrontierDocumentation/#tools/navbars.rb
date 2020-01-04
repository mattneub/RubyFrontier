def navbars()
  s_this = s_up = s_down = ""
  unless adrObject.dirname == adrSiteRootTable
    s_this = process(adrObject.dirname)
  end
  if downfolder = down_folder(adrObject)
    s_down = process(downfolder)
  end
  if !downfolder && ((upfolder = adrObject.dirname.dirname) != adrSiteRootTable)
    s_up = process(upfolder)
  end
  [s_up, s_this, s_down].join("\n") 
end
def process(what)
  embed_in_template(get_pages(what))
end
def down_folder(obj)
  downfolder = obj.dirname + (obj.simplename.to_s + "folder")
  downfolder.directory? ? downfolder : nil
end
def get_pages(dir)
  arr = Array.new
  html.pagesInFolder(dir).each do |what|
    title, path = html.getTitleAndPaths(what)
    s = if what == adrObject.simplename.to_s
      %{<span style="white-space:nowrap" markdown="1"><b>#{title}</b></span>}
    elsif what == adrObject.dirname.simplename.to_s[0..-7]
      %{<span style="white-space:nowrap" class="parent" markdown="1">#{html.getLink(title, what)}</span>}
    else
      %{<span style="white-space:nowrap" markdown="1">#{html.getLink(title, what)}</span>}
    end
    arr << s
  end
  arr
end
def embed_in_template(arr)
  return "" unless arr
  ss = <<END
  <div class="navbar">
  #{arr.join(" &nbsp;&nbsp;&nbsp; ")}
  </div>
END
  ss
end
  