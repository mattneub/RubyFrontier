def caption(img, txt)
  # generate an image-caption pair
  # how wide is the picture?
  width = html.getImageData(img)[:width] + 10
  %{
    <div style="text-align:center"><table width="#{width}"><tr><td class="pic">
    #{imageref(img)}
    </td></tr>
    <tr><td class="caption">
    #{txt}
    </td></tr>
    </table></div>
  }
end

