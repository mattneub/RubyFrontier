RUBYFRONTIER
=======

RubyFrontier is a TextMate bundle, implementing a template-based system of building Web pages and (especially) Web sites in a highly automated manner. It generates static Web pages; it isn't a Web application framework. It is excellent for heavily hyperlinked pages and for automatic generation of navigation structures such as breadcrumbs, next-prev links, etc. The system is modeled in the first instance after UserLand Frontier's `html` suite, which I documented in my [Frontier book](http://sbc.apeth.com/frontierDef/ch41.html). RubyFrontier is written in Ruby and you are expected to know Ruby and to be willing to read and to program in Ruby in order to customize and specify its behavior. It also makes some rudimentary use of [YAML][]. You can optionally employ any other cool tools you like; for example, most of my RubyFrontier sites use things like [kramdown][] and [SASS][].

For more information and full documentation, read <http://www.apeth.com/RubyFrontierDocs/>. 


GROUND OF BEING
-----

RubyFrontier is *not* a GUI tool. It is *not* for naive users. It is a programming tool for power users, and it has a learning curve: extremely full documentation and a couple of sample demonstration sites are included (one of the sample sites *is* the documentation), but you have to learn to do things the RubyFrontier way. Knowing Frontier, though not required, will help (RubyFrontier was written specifically to allow me to migrate my Web sites out of Frontier without much alteration); there are some differences, but they will be readily grasped by any former Frontier user, and I believe RubyFrontier actually does a number of things better than Frontier did.

I have moved RubyFrontier from Sourceforge to GitHub, about the beginning of October 2011, in part because Sourceforge is horrible and getting worse by the day whereas GitHub is cool, but also because I want open source to mean open source. The chief purpose of RubyFrontier is as a tool for *me*, and for me, it works. If you don't agree, you don't have to use it. If you have a positive contribution to make, feel free to report, suggest, or fork and we can go from there.

In preparation for the move to GitHub I've been writing some unit tests, thus providing some basis for believing that RubyFrontier mostly does what it's supposed to do. Because of these unit tests, along with the relative maturity and proven track record of RubyFrontier (in my own life at least), I have declared the version number 1.0 at the time of the move to GitHub, marking a milestone in the life of the code.


HISTORY
-----

For past history and version number, see the file "HISTORY" (inside the bundle).


FUTURE DIRECTIONS
-----

I have two chief goals for the long term:

* More and better unit tests. I've made a decent start, but in particular I need to get more specific about testing finer-grained parts and stages of the rendering engine.

* Compatibility with Ruby 1.9.x. I'm far from certain that Ruby 1.9.x is an unqualified success, but it is reasonable that people who use it should eventually expect RubyFrontier to work with it. Obviously the unit tests are intended, among other things, to lay the groundwork for implementing such compatibility.


DEPENDENCIES
-----

You need a Mac and TextMate. Windows / Linux users and TextMate detractors, this is not the droid you're looking for. I might eventually relax the dependency on TextMate, but for now, despite its flaws, TextMate does so much for me and for RubyFrontier that I have not bothered to consider any other milieu.

RubyFrontier was originally written under Ruby 1.8.6. I now use it under Ruby 1.8.7, and that is the version of Ruby I currently support. I would not expect RubyFrontier to work under 1.9.x yet (that is an eventual goal, however; see above).

Various parts of RubyFrontier, and the demonstration sites, use various libraries and gems, some of which you may not have installed. Many of these are initially "weak-linked", meaning that it is not a fatal error to lack them, but you'll probably want to install them anyway, as doing so can do no harm. For example, the part of RubyFrontier that deals with images uses the `exifr` gem to get the dimensions of TIFF images, but you do not need to install the `exifr` gem immediately - RubyFrontier will complain of its absence to you, but it will work just fine nevertheless as long as your Web sites have no TIFF images.


INSTALLATION
-----

Install the _RubyFrontier.tmbundle_ file in the usual TextMate way: place it in _~/Library/Application Support/TextMate/Bundles_, or just double-click it and TextMate will install it.

What I personally do is put a symlink in _~/Library/Application Support/TextMate/Bundles_ pointing to _RubyFrontier.tmbundle_. This makes it easier for me to keep the bundle in a convenient location and under version control.


PREPARATION
-----

You are expected (though not required) to have a _user.rb_ file outside the bundle. Whenever a RubyFrontier command runs, the _user.rb_ file is loaded after all of RubyFrontier's own code has loaded. Thus, _user.rb_ is your opportunity to add to or customize RubyFrontier's behavior globally (as opposed to the many customizations you can have in a particular Web site folder). For example, this is where you implement glossary entries and outline renderers that you wish to have available in all your sites. If you wanted, you could even open the PageMaker class and add or even rewrite methods, without touching the code in the bundle.

To set the location of this _user.rb_ file, use the RubyFrontier > Locate User.rb File command. Your _user.rb_ does not actually have to be called "user.rb", but it should be a Ruby file.


DOCUMENTATION
-----

The docs are available on the Web:

> <http://www.apeth.com/RubyFrontierDocs/default.html>

However, the docs are also included in RubyFrontier, and they are themselves a RubyFrontier Web site, so they are a demonstration (and test) of RubyFrontier. Choose RubyFrontier > Build RubyFrontier Docs. (Alternatively, drill down in _RubyFrontier.tmbundle_ to _Support/bin/RubyFrontier/longestJourney/docs/RubyFrontierDocumentation/default.txt_. With the _default.txt_ file selected, choose RubyFrontier > Publish Site.) After a heart-stopping pause, the documentation Web site will be built in a new folder on your Desktop and the first page of the site will open in your browser. Read and enjoy.

A shortcut to view the source for the docs (so that you can study how the docs site is constructed) is RubyFrontier > Show RubyFrontier Docs Source.


LICENSE
-----

The RubyFrontier bundle for TextMate and all its code are released under the MIT license. See the file "LICENSE" (inside the bundle).


AUTHOR
-----

Matt Neuburg (<matt@tidbits.com>, <http://www.apeth.net/matt/>)

[kramdown]: http://kramdown.rubyforge.org/
[Haml]: http://haml-lang.com/
[SASS]: http://sass-lang.com/
[YAML]: http://yaml.org/

