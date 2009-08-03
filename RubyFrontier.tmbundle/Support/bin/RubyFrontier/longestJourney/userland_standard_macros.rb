# standard rendering utilities that macros can call without prefix
# they are separate so I can determine whether a call is to one of them...
# ...but then they are included in the PageMaker class for actual calling, so they can access the current page table
# (see BindingMaker for the routing mechanism here)
module UserLand::Html::StandardMacros
  GENERATOR = "RubyFrontier"
  def linkstylesheet(sheetName, adrPageTable=@adrPageTable) # link to one stylesheet
    # you really ought to use linkstylesheets instead, it calls this for you
    # TODO: Frontier's logic for finding the style sheet (source) is much more complex
    # I just assume we have a #stylesheets folder containing .css files
    # and I also just assume we'll write it into a folder called "stylesheets" at top level
    sheetLoc = adrPageTable[:siteRootFolder] + "stylesheets" + (sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".css")
    source = adrPageTable["stylesheets"] + "#{sheetName}.css"
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    # write out the stylesheet if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing css (#{sheetName})!"
      if adrPageTable[:less]
        sheetLoc.open("w") {|io| io.write(Less.parse(source.read))}
      else
        FileUtils.cp(source, sheetLoc, :preserve => true)
      end
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    %{<link rel="stylesheet" href="#{pageToSheet}" type="text/css" />\n}
  end
  def linkjavascript(sheetName, adrPageTable=@adrPageTable) # link to one javascript
    # you really ought to use linkjavascripts instead, it calls this for you
    # TODO: as with linkstylesheet, my logic is very simplified:
    # I just assume we have a #javascripts folder and we write to top-level "javascripts"
    sheetLoc = adrPageTable[:siteRootFolder] + "javascripts" + (sheetName[0, getPref("maxfilenamelength", adrPageTable)] + ".js")
    source = adrPageTable["javascripts"] + "#{sheetName}.js"
    raise "javascript #{sheetName} does not seem to exist" unless source.exist?
    # write out the javascript if necessary
    sheetLoc.dirname.mkpath
    if sheetLoc.needs_update_from(source)
      puts "Writing javascript (#{sheetName})!"
      FileUtils.cp(source, sheetLoc, :preserve => true)
    end
    pageToSheet = sheetLoc.relative_uri_from(adrPageTable[:f]).to_s
    %{<script src="#{pageToSheet}" type="text/javascript" ></script>\n}
  end
  def embedstylesheet(sheetName, adrPageTable=@adrPageTable) # embed stylesheet
    # you really ought to use linkstylesheets instead, it calls this for you
    # TODO: as with linkstylesheet, unlike Frontier, my logic for finding the stylesheet is very simplified
    # must be in #stylesheets folder as css file, end of story
    source = adrPageTable["stylesheets"] + "#{sheetName}.css"
    raise "stylesheet #{sheetName} does not seem to exist" unless source.exist?
    s = source.read
    s = Less.parse(s) if adrPageTable[:less]
    %{\n<style type="text/css">\n<!--\n#{s}\n-->\n</style>\n}
  end
  def linkstylesheets(adrPageTable=@adrPageTable) # link to all stylesheets requested in directives
    # call this, not linkstylesheet; it lets you link to multiple stylesheets
    # new way, we maintain a "linkstylesheets" array (see incorporateDirective()), because with CSS, order matters
    # another new feature: we now permit directive embedstylesheet
    s = ""
    Array(adrPageTable[:linkstylesheets]).each do |name|
      s << linkstylesheet(name, adrPageTable)
    end
    if sheet = adrPageTable.fetch2(:embedstylesheet)
      s << embedstylesheet(sheet)
    end
    s
  end
  def linkjavascripts(adrPageTable=@adrPageTable) # link to all javascripts requested in directives
    # not in Frontier at all, but clearly a mechanism like this is needed
    # works like "meta", allowing multiple javascriptXXX directives to ask that we link to XXX
    s = ""
    adrPageTable.keys.select do |k| # key should start with "javascript" but not *be* javascript (or the folder "javascripts")
      k.to_s =~ /^javascript./i && k.to_s.downcase != "javascripts"
    end.each { |k| s << linkjavascript(k.to_s[10..-1], adrPageTable) }
    s
  end
  def metatags(htmlstyle=false, adrPageTable=@adrPageTable) # generate meta tags
    htmlText = ""
    
    # charset, must be absolutely first
    if getPref("includemetacharset", adrPageTable)
      htmlText << %{\n<meta http-equiv="content-type" content="text/html; charset=#{getPref("charset", adrPageTable)}" />}
    end
    
    # generator
    if getPref("includemetagenerator", adrPageTable)
      htmlText << %{\n<meta name="generator" content="#{GENERATOR}" />}
    end
    
    # turn directives whose name starts with "meta" into meta tag
    # e.g. directive metacool, value "RubyFrontier", generates <meta name="cool" content="RubyFrontier">
    # directive metaequivcool, value "RubyFrontier", generates <meta http-equiv="cool" content="RubyFrontier">
    adrPageTable.select {|k,v| k.to_s =~ /^meta./i}.each do |k,v| # key should start with "meta" but not *be* "meta"
      type, metaName = ((k = k.to_s) =~ /^metaequiv/i ? ["http-equiv", k[9..-1]] : ["name", k[4..-1]])
      htmlText << %{\n<meta #{type}="#{metaName}" content="#{v}" />}
    end
    
    # opportunity to insert anything whatever into head section
    # TODO: revise so that more than one insertion is possible?
    htmlText << "\n" + adrPageTable[:meta] if adrPageTable[:meta]
    
    # allow for possibility that <meta /> syntax is illegal, as in html
    htmlText = htmlText.gsub("/>",">") if htmlstyle
    htmlText + "\n"
  end
  def pageheader(adrPageTable=@adrPageTable) # generate standard page header from html tag to body tag
    # if pageheader directive exists, assume macro was explicitly called in error
    # cool because template can contain pageheader() call with or without #pageheader directive elsewhere
    return "" if adrPageTable.fetch2(:pageheader)
    # our approach is simply to provide a standard header
    # note that we do not return it! we slot it into the #pageheader directive for later processing...
    # ... and just return an empty string
    adrPageTable[:pageheader] = '
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<%= metatags() %>
<%= linkstylesheets() %>
<%= linkjavascripts() %>
<title><%= title %></title>
</head>
<%= bodytag() %>
'
    return ""
  end
  def pagefooter(t="") # generate standard page footer, just closing body and html tags
    # t param is in case extra material needs to be inserted between the tags
    # for example, might want a comment to delimit things for dreamweaver or something
    return "</body>\n#{t}\n</html>\n"
  end
  def bodytag(adrPageTable=@adrPageTable) # generate body tag, drawing attributes from directives
    # really should not be using any of these attributes! that's what CSS is for; but hey, that's Frontier
    htmltext = ""
    
    if s = adrPageTable.fetch2(:background)
      htmltext << %{ background="#{getImageData(s, adrPageTable)[:url]}" } rescue ""
    end

    attslist = %w{bgcolor alink vlink link 
      text topmargin leftmargin marginheight 
      marginwidth onload onunload
    }
    attslist.each do |oneatt|
      if s = adrPageTable.fetch2(oneatt.to_sym)
        if %w{alink bgcolor text link vlink}.include?(oneatt)
          # colors should be hex and start with #
          unless s =~ /^#/
            if s.length == 6
              unless s =~ /[^0-9a-f]/i
                s = "#" + s
              end
            end
          end
        end
        htmltext << %{ #{oneatt}="#{s}"}
      end
    end 
    "<body#{htmltext}>"
  end
  def imageref(imagespec, options=Hash.new, adrPageTable=@adrPageTable) # create img tag
    # finding the image, copying it out, and obtaining its height and width and relative url, is the job of getImageData
    imageTable = getImageData(imagespec, adrPageTable)
    options = Hash.new if options.nil? # become someone might pass nil
    height = options[:height] || imageTable[:height]
    width = options[:width] || imageTable[:width]
    htmlText = %{<img src="#{imageTable[:url]}" }
    # added :nosize to allow suppression of width and height
    htmlText << %{width="#{width}" height="#{height}" } unless (!width && !height) || options[:nosize]
    %w{name id alt hspace vspace align style class title border}.each do |what|
      htmlText << %{ #{what}="#{options[what.to_sym]}" } if options[what.to_sym]
    end
    
    # some attributes get special treatment
    # usemap, must start with #
    if (usemap = options[:usemap])
      usemap = ("#" + usemap).squeeze("#")
      htmlText << %{ usemap="#{usemap}" }
    end
    if options[:ismap]
      htmlText << ' ismap="ismap" '
    end
    # lowsrc not supported (not valid HTML any more)!
    # rollsrc, simple rollover creation
    if (rollsrc = options[:rollsrc])
      htmlText << %{ onmouseout="this.src='#{imageTable[:url]}'" }
      htmlText << %{ onmouseover="this.src='#{getImageData(rollsrc, adrPageTable)[:url]}'" }
    end
    # explanation, we now use "alt"; anyhow, there *must* be one
    unless options[:alt]
      htmlText << %{ alt="image" }
    end
    htmlText << " />"
    # neaten
    htmlText = htmlText.squeeze(" ")
    # glossref, wrap whole thing in link ready for normal handling
    # unlikely (manual <a> or html.getLink is way better) but it's Frontier, someone might want to use it
    if (glossref = options[:glossref])
      htmlText = %{<a href="#{glossref}">#{htmlText}</a>}
    end
    htmlText
  end
end

