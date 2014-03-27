
# The Gless module itself only defines a setup method; all the meat
# is in the other classes, especially {Gless::Session}.  See the
# README for a general overview; it lives at
# https://github.com/rlpowell/gless , which is also the home of this
# project.
module Gless
  # The current version number.
  VERSION = '2.0.0'

  # Sets up the config, logger and browser instances, the ordering
  # of which is slightly tricky.  If a block is given, the config, after being
  # initialized from the config file, is passed to the block, which should
  # return the new, updated config.
  #
  # @param [Hash] hash Defaults to +nil+, which is ignored.  If
  # present, this hash is used intead of reading a config file; the
  # config file is totally ignored in this case.
  #
  # @yield [config] The config loaded from the development file.  The
  #   optional block should return an updated config if given.
  #
  # @return [Gless::Logger, Gless::EnvConfig, Gless::Browser] logger, config, browser (in that order)
  def self.setup( hash = nil )
    # Create the config reading/storage object
    config = Gless::EnvConfig.new( hash )
    config = yield config if block_given?

    logger = Gless::Logger.new(
      config.get_default( "notag", :global, :tag ),
      config.get_default( false, :global, :replay ),
      config.get_default( '%{home}/public_html/watir_replay/%{tag}', :global, :replay_path )
    )

    # Get the whole backtrace, please.
    if config.get :global, :debug
      ::Cucumber.use_full_backtrace = true

      ::RSpec.configure do |config|
        # RSpec automatically cleans stuff out of backtraces;
        # sometimes this is annoying when trying to debug something e.g. a gem
        config.backtrace_clean_patterns = []
      end
    end

    # Turn on verbose (info) level logging.
    if config.get :global, :verbose
      logger.normal_log.level = ::Logger::INFO
      if logger.replay_log
        logger.replay_log.level = ::Logger::INFO
      end
      logger.debug "Verbose/info level logging enabled."
    end

    # Turn on debug level logging.
    if config.get :global, :debug
      logger.normal_log.level = ::Logger::DEBUG
      if logger.replay_log
        logger.replay_log.level = ::Logger::DEBUG
      end
      logger.debug "Debug level logging enabled."
    end

    # Create the browser.
    browser = Gless::Browser.new( config, logger )
    browser.cookies.clear

    return logger, config, browser
  end
end

Dir["#{File.dirname(__FILE__)}/gless/*.rb"].each {|r| load r }
