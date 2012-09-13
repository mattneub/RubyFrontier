def truenext()
  link = nil
  obj = @adrPageTable[:adrObject]
  unless link
    # try first down
    arr = getSubs(obj)
    link = arr[0] if arr
  end
  unless link
    # try next
    arr = html.getNextPrev(obj)
    link = arr[1] if arr[1]
  end
  unless link
    # try up and to the right
    nomad = obj
    while true
      nomad = nomad.dirname
      if nomad.to_s.downcase.end_with? "folder"
        daddy = nomad.basename.to_s[0..-7]
        if @adrPageTable[:autoglossary][daddy]
          daddyObj = @adrPageTable[:autoglossary][daddy][:adr]
          arr = html.getNextPrev(daddyObj)
          if arr[1]
            link = arr[1]
            break
          end
        end
      end
      break if nomad == @adrPageTable[:adrSiteRootTable]
    end
  end
  unless link
    return ""
  end
  # link has been set to an id suitable for use in autoglossary consultation
  title, path = html.getTitleAndPaths(link)
  return html.getLink("Next: " + title, link, :markdown => "span")
end