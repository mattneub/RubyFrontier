def caption(img, txt, xref=nil)
  # generate an image-caption pair
  # how wide is the picture?
  width = html.getImageData(img)[:width] + 10
  # now also with auto-numbering of figures, just to demonstrate
  @adrPageTable[:fignum] ||= 0
  @adrPageTable[:fignum] += 1
  fignum = "Figure " + @adrPageTable[:fignum].to_s
  makexref(xref, :fignum => fignum) if xref
  s = <<END
%div{:id => xref}
  %table(style="margin-left:auto; margin-right:auto; width:#{width}px")
    %tr
      %td(class="pic")
        #{imageref(img)}
    %tr
      %td(class="caption" markdown="span") #{fignum + ": " + txt}
END
  Haml::Engine.new(s, :ugly => true).render(Object.new, :xref => xref).gsub("\n", "")
end

