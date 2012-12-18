
# The Gless module itself only defines a setup method; all the meat
# is in the other classes, especially {Gless::Session}.  See the
# README for a general overview; it lives at
# https://github.com/rlpowell/gless , which is also the home of this
# project.
module Gless
  # The current version number.
  VERSION = '1.0.0'

  # Sets up the config, logger and browser instances, the ordering
  # of which is slightly tricky.
  #
  # @return [Gless::Logger, Gless::EnvConfig, Gless::Browser] logger, config, browser (in that order)
  def self.setup( tag )
    logger = Gless::Logger.new( tag )

    # Create the config reading/storage object
    config = Gless::EnvConfig.new( )

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
      logger.replay_log.level = ::Logger::INFO
      logger.debug "Verbose/info level logging enabled."
    end

    # Turn on debug level logging.
    if config.get :global, :debug
      logger.normal_log.level = ::Logger::DEBUG
      logger.replay_log.level = ::Logger::DEBUG
      logger.debug "Debug level logging enabled."
    end

    # Create the browser.
    browser = Gless::Browser.new( config, logger )
    browser.cookies.clear

    return logger, config, browser
  end
end

Dir["#{File.dirname(__FILE__)}/gless/*.rb"].each {|r| load r }
