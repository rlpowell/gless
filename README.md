# Gless #

A wrapper for Watir-Webdriver based on modelling web page and web site structure.

This gem attempts to provide a more robust model for web application testing,
on top of Watir-WebDriver which already has significant improvements over just
Selenium or WebDriver, based on describing pages and then interacting with the
descriptions.

Feel free to contact the author at rlpowell@digitalkingdom.org

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

## Docs ##

Other than this readme, the internal API documentation is TomDoc
markup, but using the YARD system.  Various things you can do:

* `rake doc`
 + generate the documentation
* `yard list` and `yard ri`
 + command line access to the documentation
* `yard server`
 + pretty web interface to the documentation

## Other ##

FIXME: Add a description ofthe abstraction layers wiht examples.

FIXME: Specify in detail the things the application object must have
