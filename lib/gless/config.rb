require 'yaml'

module Gless
  class Gless::EnvConfig
    def initialize
      @config = YAML::load_file "config/#{ENVIRONMENT}.yml"
    end

    def get( *args )
      return get_sub_tree( @config, *args )
    end

    def add_file file
      @config.merge!(YAML::load_file file)
    end

    private

    def get_sub_tree items, elem, *args
      if items.nil?
        raise "Could not locate '#{elem}' in YAML config" if sub_tree.nil?
      end

      new_items = items[elem.to_sym]
      raise "Could not locate '#{elem}' in YAML config" if new_items.nil?

      if args
        return get_sub_tree( new_items, *args )
      else
        return new_items
      end
    end
  end
end
