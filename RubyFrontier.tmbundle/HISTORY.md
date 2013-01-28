VERSION
=======

This is version 1.1.3.

HISTORY
=======

I started writing RubyFrontier in about January of 2008, modeling it very directly after UserLand Frontier's Web framework. By about April of 2008 it was working well enough that I was maintaining my own Web sites with it (including professional work such as the online help for Script Debugger). Then there was a long beta period where RubyFrontier was made available only to a small number of testers.

Initial public release, version 0.9, July 23, 2009. Quickly followed by 0.9.1 to handle the case where libxml wasn't installed on the user's machine. Then there was some kerfuffle over escaping shell paths, which was settled by 0.9.4.

In version 0.9.5, LESS (http://lesscss.org/) support was added, and syntax for loading and linking to JavaScript files was extended in a manner parallel to that of CSS files, making it easy to specify a particular set of JavaScript files to be loaded and linked in a particular order.

In version 0.9.6, added a new optional filter stage, `postMacroFilter.rb`, which runs after macro processing but before the autoglossary mechanism, and is expected to modify `adrPageTable[:postmacrotext]`. Also, modified `pagefooter()` to work similarly to `pageheader()`: it returns an empty string initially, so there's nothing there up through autoglossary time, and then the result is appended to the end of the page after the same sort of thing is done for the `pageheader()`. Also, fixed the bug where `html.getOneDirective` was not accepting a string argument.

In version 0.9.7, JavaScript material is now embeddable in the `<head>` area. Also, modified the behavior with respect to #images, #stylesheets, and #javascripts folders so that you can have as many as you like in the source folder and they will be written out into the rendered site. (The `:imagefoldername` directive is withdrawn and the `:maxfilenamelength` is no longer obeyed for JavaScript and stylesheet files.)

In version 0.9.8, added support for direct (calculated) templates; you can now insert the template as a string directly into the page table, instead of having to refer to a file on disk. Added support for embedding the page at a legal `<p>` tag instead of the old `<bodytext>` pseudo-tag. Added Publish Folder command. `:maxfilenamelength` is now completely withdrawn, since no one could possibly be using RubyFrontier on an old HFS file system.

In version 0.9.9, rejiggered the documentation so that it no longer uses Markdown and SmartyPants. Instead, the documentation now uses kramdown. This is faster and more predictable than using Markdown. Also, the CSS for the documentation uses LESS, and the template uses Haml. Thus the documentation itself exemplifies a modern RubyFrontier site (plus, it builds much faster now).

In version 0.9.9.1, the model site (what you get when you say RubyFrontier > New Site) was rejiggered to demonstrate "modern" features such as use of kramdown, Haml, and LESS. The documentation also takes slightly better advantage of kramdown and Haml features.

In version 0.9.9.2, moved the template-determination process forward so that `adrPageTable[:template]` is a correct Pathname by the time of the pageFilter. Rejiggered model site to match. Removed #nextprevs from the model site as it was just getting in the way in a new site.

In version 0.9.9.3, tweaked the way the autoglossary.yaml file is loaded so that it is loaded fresh in connection with the start of each page rendering; since it is also saved at the end of each page rendering, it can now be used by macros as a persistent store. (The fact that this was not the case previously was probably always a bug.) In connection with this, added a command Publish Site (No Preflight) which does not zero out and rebuild the autoglossary file before publishing a site, thus taking advantage of the autoglossary created the previous time the site was published. This mechanism can be used, for example, to implement intelligent cross-referencing.

In version 0.9.9.4, added actual cross-referencing macros, and documented them. Also, fixed a bug in a bottleneck routine, `incorporateDirective` (this bug was probably introduced in version 0.9.5, but it was exposed only under rare circumstances).

In version 0.9.9.5, added begin/rescue/end to catch invalid #prefs.yaml and #glossary.yaml files.

In version 0.9.9.6, added ERB (macro) processing of CSS stylesheets and JavaScript scripts; this is intended to make it easier for them to refer to images. Some additional very minor tweaks: improved on rescue messages from previous commit; minor edits in documentation.

In version 0.9.9.7, replaced LESS support with SASS support. Also, started writing unit tests.

In version 0.9.9.8, removed both LESS and SASS support, and in their place introduced the cssFilter which leaves it up to you whether and how you want to process CSS. The documentation and the New Site model site are recast to demonstrate the new technique. Also, improved the `nextprevlinks.rb` tool script that comes with the New Site model site (and PageMaker's `pagesInFolder` utility now filters out empty lines from the #nextprevs.txt file instead of throwing an error).

In version 1.0, cleaned up cruft in the CSS processing processing routines, especially for embedded CSS. More unit tests. Migrated from svn to git. Changed the README file to this HISTORY file, and placed a revised README.md file at top level where GitHub will see it.

In version 1.0.1, expanded the user.rb mechanism to allow inclusion of a #user.rb file at the top level of the site folder; also improved the error message when a user.rb file fails to load. Documentation updated.

In version 1.0.2, introduced a mechanism to allow a `.txt` file to function as an outline (like a `.opml`) file, by using indentation and setting the `:treatasopml` directive to `true`. Documentation updated.

In version 1.1, support for Ruby 1.9.3 was added, along with some general code cleanup. Dependency on exifr removed, replaced by dependency on dimensions. Improved message/exception formatting.

In version 1.1.1, some tweaks were made to improve message/exception formatting even more (and fixed a test that was broken by this change). Improved reporting of syntax errors in tools. Fixed the JPEG dimensions calculation to work with Ruby 1.9.3, even though we aren't using it any more (it's fixed but commented out). Corrected a bug caused by removal of the autoglossary from the repository. The most important change is a huge speedup in rebuilding the autoglossary (Preflight Site, Publish Site).

In version 1.1.2, tests were revised to use MiniTest (and were rewritten and rationalized in the process); all tests pass on both Ruby 1.8.7 and Ruby 1.9.3. Pathname#relative_uri_from was completely rewritten from the ground up, so that we are no longer dependent on the formatting quirks of URI::Generic. The implementation of nextprevlinks in the model site was corrected (it was never right!) and the documentation was adjusted to match. The newSite method can now be invoked programmatically with a parameter saying where to create the site folder. Added a tentative implementation of #<< for FakeStdout (needed by pp, apparently).

In version 1.1.3, an output bug was fixed (thanks, hdmw): warnings were being overwritten by subsequent output, perhaps due to changes in version 1.1. Also improved the README to describe the warnings and what you're supposed to do (or not do) about them, and to explain how to run the tests.

