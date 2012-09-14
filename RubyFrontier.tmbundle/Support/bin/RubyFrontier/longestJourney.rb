$: << File.dirname(__FILE__)
# utilities: myrequire, myraise, Memoizable, and various modifications to existing classes
require 'longestJourneyUtilities.rb'

myrequire "pathname", "yaml", "erb", "pp", "uri", "rubygems", "dimensions", "enumerator", "kramdown", "haml", "sass", "nokogiri"
begin
  YAML::ENGINE.yamler = 'syck' # otherwise our speed is cut in *half* on Ruby 1.9.3
rescue
end
=begin make 'load' and 'require' include folder next to, and with same name as, this file 
that is where supplementary files go
uses our Pathname convenience method so we couldn't do this until now
=end
p = Pathname.new(__FILE__)
ljfolder = p.dirname + p.simplename
$: << ljfolder.to_s
$usertemplates = ljfolder + "user" + "templates"
$newsite = ljfolder + "newsite"

require 'opml'

=begin environment in which macro evaluation and outline rendering takes place
  this is all done for maximum similarity to Frontier, and for sheer convenience
  user is guaranteed that current PageMaker instance's @adrPageTable is in scope
    thus user can say @adrPageTable[:fname] to get current page's fname
  user is allowed to say certain words in abbreviated form:
    * "html." can mean Html class (html.getLink) or current PageMaker instance (html.getPref)
      in latter ca*se, no need to supply default params, since this is the current instance
    * "myTool()" can be myTool.rb in a #tools folder, defining method myTool()
    * "imageref()" can be StandardMacros method
      separated into StandardMacros for namespace clarity...
      ...but in fact subsumed into the PageMaker instance, so again, no need to supply default params
    * "fname" can be @adrPageTable[:fname] or @adrPageTable["fname"]
      good for getting, but doesn't work for setting, as Ruby will just create the name as local variable
      and not highly recommended for getting either, since confusing to read, and @adrPageTable is readily available
      but's a Frontier legacy so I've left it in (and I d*o use it)
=end
class BindingMaker
  def html # if user's expression starts with "html", return object with method_missing to handle rest of expression
    # so we need to send back an object that will allow us to hear about the *next* word ("getLink" etc.)
    # its job is to choose between, and dispatch to, either the Html class or the PageMaker instance
    # to make the latter possible, we capture a ref to the PageMaker instance
    itsPageMaker = @thePageMaker
    Module.new do
      class << self; self; end.send(:define_method, :method_missing) do |s, *args|
        if UserLand::Html.respond_to? s
          return UserLand::Html.send(s, *args)
        else
          return itsPageMaker.send(s, *args)
        end
      end
    end
  end
  # handle shortcut / bareword expressions in macro evaluation
  def method_missing(s, *args)
    # if starts with html., we are not called, html method above handled it
    # test for user.html.macros not needed, since user can inject into UserLand::Html via user.rb
    # test for tools table not needed, they are part of this BindingMaker object already

    # try html.standardMacros; it is included into PageMaker
    return @thePageMaker.send(s, *args) if UserLand::Html::StandardMacros.method_defined?(s)
    
    # try adrPageTable; unlike Frontier, and wisely I think, we allow implicit get but no implicit set
    if 0 == args.length and result = @adrPageTable.fetch2(s)
      return result 
    end
    
    begin
      super
    rescue Exception => e
      raise e.exception("BindingMaker unable to evaluate '#{s}'")
    end
  end
  def getBinding(); return binding(); end
  def initialize(thePageMaker)
    @thePageMaker = thePageMaker # so we can access it later
    @adrPageTable = thePageMaker.adrPageTable # so macros can get at it
  end
  attr_reader :thePageMaker
end

# open modules we will be defining; think of this as an outline of our structure
module UserLand
end
module UserLand::Html
  # module's class methods will go here
  # class PageMaker will go here
end
module UserLand::Html::StandardMacros
  # PageMaker includes these too
end
module UserLand::User
end
module UserLand::Renderers
  # class SuperRenderer will go here
end

# load the real code

myrequire 'userland_renderers'

myrequire 'userland_class_methods'

myrequire 'userland_standard_macros'

myrequire 'userland_pagemaker'

# load user.rb last of all, so user can define SuperRenderer subclass and use "user.rb" for overrides of anything
# location of user.rb is outside the bundle and is defined in a global $userrb
# we supply an easy way to do this via "Locate user.rb File" command, which puts value into user defaults

f = `defaults read com.neuburg.matt.rubyFrontier userrb 2>/dev/null`
$userrb = f.chomp
myrequire $userrb rescue puts "Did not load a user.rb file. If you have a user.rb file, specify it with Locate user.rb File command. (If you've done that, your user.rb file may be generating an error on load.)"


