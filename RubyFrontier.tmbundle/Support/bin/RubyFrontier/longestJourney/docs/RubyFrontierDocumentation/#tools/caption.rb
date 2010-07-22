def caption(img, txt)
  # generate an image-caption pair
  # how wide is the picture?
  width = html.getImageData(img)[:width] + 10
  %{
<div><table style="margin-left:auto; margin-right:auto; width:#{width}px"><tr><td class="pic">
#{imageref(img)}
</td></tr>
<tr><td class="caption" markdown="span">
#{txt}
</td></tr>
</table></div>
  }.gsub("\n", "")
end

