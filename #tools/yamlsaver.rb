require "yaml"
s = { 
  :bgcolor => "FFFFFF", 
  :dolinkback => false, 
  :dreamweaver => false,
  :halo_shortcut => "|",
  :haloautoparagraphs => true,
  :includeMetaCharset => true,
  :includeMetaGenerator => true,
  :renderoutlinewith => "halo",
  :smartypants => true,
  :templateNOT => "dreamweaver",
  :useImageCache => false,
  :usestylesheet => "styles"
}
p = Pathname.new("~/Desktop/#prefs.yaml")
p = p.expand_path
p.open("w") {|f| YAML::dump(s, f)}