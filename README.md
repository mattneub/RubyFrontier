RUBYFRONTIER
=======

RubyFrontier is a TextMate bundle, implementing a template-based system of building Web pages and (especially) Web sites in a highly automated manner. It generates static Web pages; it isn't a Web application framework. Its purpose is to make Web sites by way of a convenient writing tool, separating form from content (you concentrate on content, and RubyFrontier wraps up that content into Web page form when you build the site). RubyFrontier is excellent for heavily hyperlinked pages and for automatic generation of navigation structures such as breadcrumbs, next-prev links, etc. The system is modeled in the first instance after UserLand Frontier's `html` suite, which I documented in my [Frontier book](http://sbc.apeth.com/frontierDef/ch41.html). RubyFrontier is written in Ruby and you are expected to know Ruby and to be willing to read and to program in Ruby in order to customize and specify its behavior. It also makes some rudimentary use of [YAML][]. You can optionally employ any other cool tools you like; for example, most of my RubyFrontier sites use things like [kramdown][] and [SASS][].

For more information and full documentation, read <http://www.apeth.com/RubyFrontierDocs/>. The documentation is itself a RubyFrontier-built site, and the source for the documentation is included with RubyFrontier so you can see how it's done.

For another example site, see my [documentation for Script Debugger 5](http://www.apeth.com/sd5help/index.html).


GROUND OF BEING
-----

RubyFrontier is *not* a GUI tool. It is *not* for naive users. It is a programming tool for power users, and it has a learning curve: extremely full documentation and a couple of sample demonstration sites are included, but you have to learn to do things the RubyFrontier way. Knowing Frontier, though not required, will help (RubyFrontier was written specifically to allow me to migrate my Web sites out of Frontier without much alteration); there are some differences, but they will be readily grasped by any former Frontier user, and I believe RubyFrontier actually does a number of things better than Frontier did.

I moved RubyFrontier from Sourceforge to GitHub, about the beginning of October 2011, in part because Sourceforge is horrible and getting worse by the day whereas GitHub is cool, but also because I wanted open source to mean open source. The chief purpose of RubyFrontier is as a tool for *me*, and for me, it works. If you don't agree, you don't have to use it. If you have a positive contribution to make, feel free to [report][], suggest, or fork and we can go from there.


HISTORY
-----

In preparation for the move to GitHub in October 2011 I wrote some unit tests, thus providing some basis for believing that RubyFrontier mostly does what it's supposed to do. Because of these unit tests, along with the relative maturity and proven track record of RubyFrontier (in my own life at least), I declared the version number 1.0 at the time of the move to GitHub, marking a milestone in the life of the code.

In September 2012 another milestone was reached: RubyFrontier started working under Ruby 1.9.3.

In December 2013 I started using RubyFrontier with TextMate 2 under Mavericks (OS X 10.9, Ruby 2.0.0).

For past history and version number, see the file "HISTORY" (inside the bundle).


DEPENDENCIES
-----

You need a Mac and TextMate. Windows / Linux users and TextMate detractors, this is not the droid you're looking for. I might eventually relax the dependency on TextMate, but for now, despite its flaws, TextMate does so much for me and for RubyFrontier that I have not bothered to consider any other milieu.

RubyFrontier was originally written under Ruby 1.8.6, and I then used it for a long time under Ruby 1.8.7. In September 2012 I installed Ruby 1.9.3 and spent some time tweaking, and I am happy to say that RubyFrontier now appears to be working equally under Ruby 1.8.7 and 1.9.3. By "working equally" I mean that:

1. All tests pass. You could argue that the tests are a little weak and don't hit certain edge cases or go very deep into the page/site-building mechanism, and that's true enough. But it's something. And...

2. All my own sites build correctly.

Therefore I now permit use of RubyFrontier under Ruby 1.9.3. As of this point (version 1.1.1 and later) I am quite confident about this feature. If you do encounter an issue, please [report][] it. If the Ruby 1.9.3 tweaks worry you, stick with Ruby 1.8.7 and use commit 611d787958, but in my opinion the current version is better, under both Ruby 1.8.7 and Ruby 1.9.3.

In February 2013 Ruby 2.0.0 was released. RubyFrontier appears to work well under Ruby 2.0.0. Again, if there's a problem, please [report][] it.

In December 2013 I installed Mavericks (OS X 10.9), which force-updates you to Ruby 2.0.0. At that point, it seemed easiest to give TextMate 2 a try. RubyFrontier appears to run fine under Mavericks and TextMate 2! The proof is the same as above: all tests pass, and my own sites build correctly. Please let me know of any issues you encounter.


INSTALLATION
-----

Install the _RubyFrontier.tmbundle_ file in the usual TextMate way: place it in _~/Library/Application Support/TextMate/Bundles_, or just double-click it and TextMate will install it.

What I personally do is put a symlink in _~/Library/Application Support/TextMate/Bundles_ pointing to _RubyFrontier.tmbundle_. This makes it easier for me to keep the bundle in a convenient location and under version control.


PREPARATION
-----

Various parts of RubyFrontier, and the demonstration sites, use various libraries and gems, some of which you may not have installed. Many of these are initially "weak-linked", meaning that it is not a fatal error to lack them, but you'll probably want to install them anyway, as doing so can do no harm. For example, the part of RubyFrontier that deals with images uses the `dimensions` gem to get the dimensions of images, but you do not need to install the `dimensions` gem immediately - RubyFrontier will complain of its absence to you, but it will work just fine nevertheless as long as your Web sites have no images.

You should see a good set of warnings if you choose RubyFrontier > Build RubyFrontier Docs. The idea is that you should install a missing gem and then try again until the docs build successfully. Rinse, lather, repeat. Once you build the docs successfully you can relax; you can live happily with warnings about things that don't affect you.

You are permitted (though not required) to have a _user.rb_ file outside the bundle. Whenever a RubyFrontier command runs, the _user.rb_ file is loaded after all of RubyFrontier's own code has loaded. Thus, _user.rb_ is your opportunity to add to or customize RubyFrontier's behavior globally (as opposed to the many customizations you can have in a particular Web site folder, plus there is also a mechanism for keeping a _user.rb_ in an individual site folder). For example, this is where you implement glossary entries and outline renderers that you wish to have available in all your sites. If you wanted, you could even open the PageMaker class and add or even rewrite methods, without touching the code in the bundle.

To set the location of this _user.rb_ file, use the RubyFrontier > Locate User.rb File command. Your _user.rb_ does not actually have to be called "user.rb", but it should be a Ruby file.


TESTS
-----

The tests require a knowledge of where TextMate is. So there are two ways to run the tests:

* In TextMate, open RubyFrontier, find the tests, and run each one individually.

* Alternatively, use the Rakefile. This is more work, but it has the advantage that you are not dependent on TextMate's notion of what Ruby version is in force. The Rakefile, however, expects an environment variable `TM_SUPPORT_PATH` to tell it where TextMate's `TM_SUPPORT_PATH` is. So figure that out in advance; a good way is to run a Ruby script inside TextMate:

        puts ENV["TM_SUPPORT_PATH"]

    In the Terminal, `cd` to the folder containing the _Rakefile_ and then say the equivalent of this, substituting your support path:

        rake TM_SUPPORT_PATH='/path/to/support/folder' test

Warnings (the same warnings mentioned in the previous section) are unimportant. One `tc_pathname.rb` test skips; this is deliberate. You should see 0 failures and 0 errors.

DOCUMENTATION
-----

The docs are available on the Web:

> <http://www.apeth.com/RubyFrontierDocs/default.html>

However, the docs are also included in RubyFrontier, and they are themselves a RubyFrontier Web site, so they are a demonstration (and test) of RubyFrontier. Choose RubyFrontier > Build RubyFrontier Docs. After a heart-stopping pause, the documentation Web site will be built in a new folder on your Desktop and the first page of the site will open in your browser. Read and enjoy.

Alternatively, choose RubyFrontier > Show RubyFrontier Docs Source. This command is so that you can study how the docs site is constructed. You can then also build the docs by selecting the _default.txt_ file and then choosing RubyFrontier > Publish Site. 

FUTURE DIRECTIONS
-----

Now that RubyFrontier is usable with Ruby 1.9.3 (and Ruby 2.0.0), my chief goal is more and better unit tests. Eventually I would like to withdraw support for Ruby 1.8.7 and anything earlier than Ruby 1.9.3. If TextMate 2 under Mavericks keeps working for me, I will probably eventually drop support for TextMate 1 and anything earlier than Ruby 2.0.0. But we are a long way from that.

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
[report]: https://github.com/mattneub/RubyFrontier/issues

