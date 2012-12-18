# Gless #

A wrapper for Watir (specifically watir-webdriver, which is built on
top of selenium-webdriver) based on modelling web page and web site
structure.  It's intended to make it easier to model complex
application workflow in an RSpec or Cucumber web site test suite.

This gem attempts to provide a more robust model for web application testing,
on top of Watir-WebDriver which already has significant improvements over just
Selenium or WebDriver, based on describing pages and then interacting with the
descriptions.

Feel free to contact the author at rlpowell@digitalkingdom.org

## Overview And Motivation ##

Gless takes Watir elements and collects them into pages.  It then
inserts a session layer on top of the pages.  The session layer is
in charge of knowing what page the browser is on, managing
transitions, and checking that they worked.  On top of this sits an
application layer, which is the code that uses Gless for its
testing.

The motivation is seperation of testing types.

At the page level, which is code provided by a user of Gless, the
code has very little error correction, and mostly consists of just
the elements themselves, but might have some light code tying
elements together.  For example, a "log me in" method that simply
takes a username and password and clicks the login button, and does
no error checking at any step, would go here.

At the session level, which is part of Gless itself and if you need
more features please send me a pull request, are various functions
to do page-level error correction.  The big one here is long\_wait,
which watches a page for changes and only moves on when it sees what
it expects.

At the application level, which is code provided by a user of Gless,
you can write any multi-page workflows you like, without having to
pay any real attention to what page your on in the code, except in
as much as if your interactions don't match the site workflow your
tests are likely to fail. :)  For example, a method to register an
account from scratch and log in with it, which presumably involves
several site pages, would go here.

## An Example ##

The best way to see how to use this library is to look in the
examples/ directory, but here's some stripped down examples.

A partial page definition:

```ruby
    element :home     , :link , :href => "https://github.com/"         , :validator => true , :click_destination => :LoginPage
    element :explore  , :link , :href => "https://github.com/explore"  , :validator => true , :click_destination => :ExplorePage
    element :search   , :link , :href => "https://github.com/search"   , :validator => true , :click_destination => :SearchPage

    element :search_input  , :text_field  , :class => 'text'  , :validator => true
    element :search_button , :button , :text => 'Search' , :validator => true

    url %r{^:base_url/search}

    expected_title %r{^(Code Search · GitHub|Search · \S+ · GitHub)$}
```

Given that definition, whenever the session code detects that it
*should* be on the search page (i.e. when the "search" element is
clicked), all of those elements will be checked for existence, the
url will be checked, and the title will be checked.

All of that is entirely automatic; the code that would trigger all
that would just be

  @session.search.click

An example of page code that might use such a page definition:

```ruby
def search_for stuff
  self.search_input.set stuff
  self.search_button.click
end
```

An example of applicaiton level code that might use that page level
code (plus some other stuff not shown here):


```ruby
def search_and_go name
  @session.search.click
  @session.search_for name
  @session.goto_repository name
end
```

As you can see, the application level can encode extremely
complicated actions, in this case "go to the search page, search for
a repository, and go to that repository page", in a compact way that
has a sensible abstraction pattern.

## Writing Code Around Gless ##

### Configuration File ###

Gless expects you to have a configuration file named
lib/config/development.yml (the word "development" there can be
altered by changing the ENVIRONMENT environment variable) under your
test application.  See examples/ for a detailed example.

The parts that Gless uses directly, and hence are required:

```yaml
:global: # This tag distinguishes the global config from the per-test configs; *do not remove*
  :debug: false
  :thumbnails: false    # Whether to create small-ish "thumbnail" pictures on the replay page; requires the imagemagick system package and the mini_magick gem
  :browser:
    :type: local                # Local or remote
    :browser: firefox   # Which browser to use
    :port: 4444         # If remote, port to connect to the selenimu server, otherwise ignored
```

### The Pages ###

All of your site page description classes *must* be descendants of Gless::BasePage.

It is often useful to have your own base page class as well for
headers and footers and so on.  See examples/ for a complete example
as usual, but here's a partial one:


```ruby
rpowell@ut00-s00000> cat examples/test_github/lib/pages/test_github_base_page.rb
module TestGithub
  class TestGithub::BasePage < Gless::BasePage

    element :home     , :link , :href => "https://github.com/"         , :validator => true , :click_destination => :LoginPage
    element :explore  , :link , :href => "https://github.com/explore"  , :validator => true , :click_destination => :ExplorePage
    element :search   , :link , :href => "https://github.com/search"   , :validator => true , :click_destination => :SearchPage
    element :features , :link , :href => "https://github.com/features" , :validator => true , :click_destination => :FeaturesPage
    element :blog     , :link , :href => "https://github.com/blog"     , :validator => true , :click_destination => :BlogPage

  end

  class BlogPage < TestGithub::BasePage

    url %r{^:base_url/blog$}

    expected_title 'The Official GitHub Blog · GitHub'

    # Stub page, but BasePage stuff still works

  end
end
```

### The Application ###

Your application layer that sits on top of Gless must itself have
certain features, as other aspects of Gless do call back into the
application layer and/or make use of it.  Here's some minimal
boilerplate that you should start with:

```ruby
module TestGithub

  class TestGithub::Application
    include RSpec::Matchers

    attr_accessor :browser
    attr_accessor :session
    attr_accessor :site
    attr_accessor :base_url

    def initialize( browser, config, logger )
      @logger = logger
      @browser = browser
      @config = config

      @session = Gless::Session.new( @browser, @config, @logger, self )

      @session.should be_true
    end
end
```

## Debugging Gless Applications/Tests ##

If your configuration file has ":debug: true", then Gless will
produce some pretty verbose logging of what it's doing.

A less crazy version is ":verbose: true".

It will also create a replay log directory which is intended to be
viewed in a browser.  The directory location defaults to
~/public_html/watir_replay/test/ ; the initialization of
Gless::Logger determines that location.  Most actions that Gless
performs will cause the replay log to be updated a copy of the HTML
source as Gless/Watir/Selenium/WebDriver sees it.

If you have ":screenshots: true" (along with debugging), screenshots
will also be taken showing the visual state of the browser at the
time.  This is quite slow, especially if the page is large.  In
addition, if you have imagemagick installed, and the mini_magick
gem, and ":thumbnails: true", then smaller pictures will be included
on the main replay index page, rather than the full-sized ones.

## Requirements ##

Ruby 1.9.3 is used for development of this project.

Gless expects that you're running tests under RSpec or Cucumber;
significant modification would likely be required to make it run
otherwise, as it uses RSpec's `should` extensively.

The following should be sufficient to allow all the rake tasks to
run:

    gem install yard-tomdoc redcarpet watir-webdriver rspec

In addition, you'll need the mini\_magick gem and the imagemagick OS
package if you want thumbnails in the logging output.

## Tests ##

Gless doesn't have any; if you can tell me how I should test something
like this besides "just run the sample app", please feel free to
suggest.

## Documentation ##

Other than this readme, the internal API documentation is in YARD
markup.  Various things you can do:

* `rake doc`
 + generate the documentation
* `yard list` and `yard ri`
 + command line access to the documentation
* `yard server`
 + pretty web interface to the documentation

