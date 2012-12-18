require 'yaml'

module Gless
  # Provides a bit of a wraper around yaml config files; nothing
  # terribly complicated.  Can merge multiple configs together.
  # Expects all configs to be hashes.
  class Gless::EnvConfig
    # Bootstrapping method used to inform Gless as to where
    # config files can be found.
    #
    # @param [String] dir The directory name that holds the config
    #   files (under lib/config in said directory).
    #
    # @example
    #
    #   Gless::EnvConfig.env_dir = File.dirname(__FILE__)
    #
    def self.env_dir=(dir)
      @@env_dir=dir
    end

    # Sets up the initial configuration environment. @@env_dir must
    # be set before this, or things will go poorly.
    # The file it wants to load is, loosely,
    # @@env_dir/lib/config/ENVIRONMENT.yml, where ENVIRONMENT is the
    # environment variable of that name.
    #
    # @return [Gless::EnvConfig]
    def initialize
      env = (ENV['ENVIRONMENT'] || 'development').to_sym

      env_file = "#{@@env_dir}/config/#{env}.yml"
      raise "You need to create a configuration file named '#{env}.yml' (generated from the ENVIRONMENT environment variable) under #{@@env_dir}/lib/config" unless File.exists? env_file

      @config = YAML::load_file env_file
    end

    # Add a file to those in use for configuration data.
    # Simply merges in the new data, so each file should probably
    # have its own top level singleton hash.
    #
    def add_file file
      @config.merge!(YAML::load_file "#{@@env_dir}/#{file}")
    end

    # Get an element from the configuration.  Takes an arbitrary
    # number of arguments; each is taken to be a hash key.
    #
    # @example
    #
    #  @config.get :global, :debug 
    #
    # @return [Object] what's left after following each key; could be
    #   basically anything.
    def get( *args )
      return get_sub_tree( @config, *args )
    end

    private

    # Recursively does all the heavy lifting for get
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
