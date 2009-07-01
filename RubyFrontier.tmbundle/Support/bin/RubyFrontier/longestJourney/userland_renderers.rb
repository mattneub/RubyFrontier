=begin superclass from which outline renderers are to inherit
this allows outline renderers to enjoy the same environment as macro evaluation (see on BindingMaker, above)
(this is not a Frontier feature, but it sure should be! makes life a lot easier;
e.g. you can reach @adrPageTable, tools, Html methods really easily)
so, an outline renderer must be a class deriving from UserLand::Renderers::SuperRenderer
subclasses should not override "initialize" without calling super or imitating
subclasses must implement "render(op)" where "op" is an Opml object (see opml.rb)
=end


class UserLand::Renderers::SuperRenderer
  def initialize(thePageMaker, theBindingMaker)
    @thePageMaker = thePageMaker # so we can access it later
    @adrPageTable = thePageMaker.adrPageTable # so macros can get at it
    @theBindingMaker = theBindingMaker # to provide macro evaluation environment
  end
  def method_missing(s, *args)
    @theBindingMaker.send(s, *args) # delegation (fixes bug, previously I was sending straight to method_missing)
  end
  def render
    raise "Renderer failed to implement render()"
  end
end
