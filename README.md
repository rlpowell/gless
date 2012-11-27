# Gless #

A wrapper for Watir-Webdriver based on modelling web page and web site structure.

This gem attempts to provide a more robust model for web application testing,
on top of Watir-WebDriver which already has significant improvements over just
Selenium or WebDriver, based on describing pages and then interacting with the
descriptions.

Feel free to contact the author at rlpowell@digitalkingdom.org

## Requirements ##

Ruby 1.9.3 is used for development of this project.

The following should be sufficient to allow "rake build" to work:

    gem install yard-tomdoc watir-webdriver cucumber

### External Deps ###

* RSpec and Cucumber for the running of the actual web tests that this gem supports
* yard and yard-tomdoc for documentation
* mini\_magick and the imagemagick package for your OS if you want thumbnails in the logging

### Standard Libary Deps ###

* FIXME: ??

## Tests ##

Doesn't have any; if you can tell me how I should test something
like this besides "just run the sample app", please feel free to
suggest.
