# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gless/version"

Gem::Specification.new do |s|
  s.name        = "gless"
  s.version     = Gless::VERSION
  s.authors     = ["Robin Lee Powell"]
  s.email       = ["rlpowell@digitalkingdom.org"]
  s.homepage    = "http://github.com/rlpowell/gless"
  s.summary     = %q{A wrapper for Watir-WebDriver based on modelling web page and web site structure.}
  s.description = %q{This gem attempts to provide a more robust model for web application testing, on top of Watir-WebDriver which already has significant improvements over just Selenium or WebDriver, based on describing pages and then interacting with the descriptions.}

  s.add_dependency 'cucumber'  # FIXME: Actually needed?
  s.add_dependency 'rspec'  # FIXME: Actually needed?
  s.add_dependency 'watir-webdriver'
  s.add_development_dependency 'debugger'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'yard-tomdoc'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
