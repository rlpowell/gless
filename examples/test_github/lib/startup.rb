$: << File.dirname(__FILE__)

require 'rubygems'
require 'optparse'
require 'yaml'
require 'watir-webdriver'

require 'gless'

Gless::EnvConfig.env_dir = File.dirname(__FILE__)

require 'pages/test_github_base_page'
Dir["#{File.dirname(__FILE__)}/pages/*/*_page.rb"].each {|r| load r }
Dir["#{File.dirname(__FILE__)}/pages/*_page.rb"].each {|r| load r }

require 'test_github'
