require 'yaml'

module Gless
  class Gless::EnvConfig
    def self.env_dir=(d)
      @@env_dir=d
    end

    def initialize
      print "ed: #{@@env_dir}" # FIXME: 

      env = (ENV['ENVIRONMENT'] || 'development').to_sym

      env_file = "#{@@env_dir}/config/#{env}.yml"
      raise "You need to create a configuration file named '#{env}.yml' (generated from the ENVIRONMENT environment variable) under #{@@env_dir}/lib/config" unless File.exists? env_file

      @config = YAML::load_file env_file
    end

    def get( *args )
      return get_sub_tree( @config, *args )
    end

    def add_file file
      @config.merge!(YAML::load_file file)
    end

    private

    def get_sub_tree items, elem, *args
      # Can't use debug logging here, as it maybe isn't turned on yet
      # puts "In Gless::EnvConfig, get_sub_tree: items: #{items}, elem: #{elem}, args: #{args}"

      if items.nil?
        raise "Could not locate '#{elem}' in YAML config" if sub_tree.nil?
      end

      new_items = items[elem.to_sym]
      raise "Could not locate '#{elem}' in YAML config" if new_items.nil?

      if args.empty?
        return new_items
      else
        return get_sub_tree( new_items, *args )
      end
    end
  end
end
