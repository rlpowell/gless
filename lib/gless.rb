
module Gless
  VERSION = '0.0.1'
end

Dir["#{File.dirname(__FILE__)}/gless/*.rb"].each {|r| load r }