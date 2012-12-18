
module Gless
  # The current version number.
  VERSION = '1.0.0'
end

Dir["#{File.dirname(__FILE__)}/gless/*.rb"].each {|r| load r }
