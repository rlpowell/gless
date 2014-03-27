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
    def initialize( hash = nil )
      if hash
        @config = hash
      else
        @env = (ENV['ENVIRONMENT'] || 'development').to_sym

        env_file = "#{@@env_dir}/config/#{@env}.yml"
        raise "You need to create a configuration file named '#{@env}.yml' (generated from the ENVIRONMENT environment variable) under #{@@env_dir}/lib/config" unless File.exists? env_file

        @config = YAML::load_file env_file
      end
    end

    # Add a file to those in use for configuration data.
    # Simply merges in the new data, so each file should probably
    # have its own top level singleton hash.
    #
    def add_file file
      @config.merge!(YAML::load_file "#{@@env_dir}/#{file}")
    end

    # Get an element from the configuration.  Takes an arbitrary
    # number of arguments; each is taken to be a hash key.  With no
    # arguments, returns the whole configuration.
    #
    # @example
    #
    #  @config.get :global, :debug 
    #
    # @return [Object] what's left after following each key; could be
    #   basically anything.
    def get( *args )
      r = get_default nil, *args
      raise "Could not locate '#{args.join '.'}' in YAML config; please ensure that '#{@env}.yml' is up to date." if r.nil?
      r
    end

    # Optionally get an element from the configuration, otherwise returning the
    # default value.
    #
    # @example
    #
    #  @config.get_default false, :global, :cache
    #
    # @return [Object] what's left after following each key, or else the
    #   default value.
    def get_default( default, *args )
      if args.empty?
        return @config
      end

      r = get_sub_tree( @config, *args )
      r.nil? ? default : r
    end

    def merge(hash)
      @config.merge!(hash)
    end

    def deep_merge(b)
      iter = -> a, step {a.merge(step) {|key, oldval, newval| [oldval, newval].all? {|v| v.kind_of? Hash} ? iter.(oldval, newval) : newval}};
      @config = iter.(@config, b)
    end

    # Set an element in the configuration to the given value, passed after all
    # of the indices.
    #
    # @example
    #
    #  @config.set :global, :debug, true
    def set(*indices, value)
      set_root @config, value, *indices
    end

    private

    def set_root root, value, *indices
      if root[indices[0]] == nil
        root[indices[0]] = Hash.new
      end
      if indices.length > 1
        set_root root[indices[0]], value, *indices[1..-1]
      else
        root[indices[0]] = value
      end
    end

    # Recursively does all the heavy lifting for get
    def get_sub_tree items, elem, *args
      # Can't use debug logging here, as it maybe isn't turned on yet
      # puts "In Gless::EnvConfig, get_sub_tree: items: #{items}, elem: #{elem}, args: #{args}"

      return nil if items.nil?

      new_items = items[elem.to_sym]
      return nil if new_items.nil?

      if args.empty?
        return new_items
      else
        return get_sub_tree( new_items, *args )
      end
    end
  end
end
