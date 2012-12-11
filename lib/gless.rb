
module Gless
  VERSION = '0.0.1'
end

load "#{File.dirname(__FILE__)}/gless/logger.rb"

# Used by "elemnt" and similar class-level code in BasePage
$master_logger = Gless::Logger.new(:master, false)

Dir["#{File.dirname(__FILE__)}/gless/*.rb"].each {|r| load r }
