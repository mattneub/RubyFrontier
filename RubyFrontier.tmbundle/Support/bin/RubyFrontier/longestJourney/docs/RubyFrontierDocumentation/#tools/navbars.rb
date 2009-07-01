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
    title, path = html.getTitleAndPath(what)
    s = if what == adrObject.simplename.to_s
      %{<b>#{title}</b>}
    elsif what == adrObject.dirname.simplename.to_s[0..-7]
      %{<span class="parent">#{html.getLink(title, what)}</span>}
    else
      html.getLink(title, what)
    end
    arr << %{<span style="white-space:nowrap">#{s}</span>}
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
  