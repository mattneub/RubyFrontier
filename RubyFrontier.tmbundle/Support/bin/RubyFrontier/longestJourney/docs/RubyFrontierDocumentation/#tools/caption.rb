def caption(img, txt)
  # generate an image-caption pair
  # how wide is the picture?
  width = html.getImageData(img)[:width] + 10
  s = <<END
%div
  %table(style="margin-left:auto; margin-right:auto; width:#{width}px")
    %tr
      %td(class="pic")
        #{imageref(img)}
    %tr
      %td(class="caption" markdown="span") #{txt}
END
  Haml::Engine.new(s, :ugly => true).render.gsub("\n", "")
end

