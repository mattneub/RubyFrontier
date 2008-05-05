def linkback()
  return "" unless html.getPref(:dolinkback, @adrPageTable)
  f = @adrPageTable[:adrObject]
  url = "file://" + ERB::Util::url_encode(f)
  return html.getLink("linkback", "txmt://open/?url=" + url)
end