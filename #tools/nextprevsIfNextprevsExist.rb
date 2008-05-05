def nextprevsIfNextprevsExist()
  obj = @adrPageTable[:adrObject]
  npt = obj.dirname + "#nextprevs"
  return "" unless npt.exist?
  # rest not yet written
  return "<p>error, nextprevs routine not yet written</p>"
end