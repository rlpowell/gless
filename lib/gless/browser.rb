module Gless
  class Gless::Browser
    attr_reader :browsar

    def initialize( config )
      @config = config
      Logging.log.debug "Launching some browser; #{@config.get_config :global, :browser, :type}, #{@config.get_config :global, :browser, :port}"

      if (@config.get_config :global, :browser, :type) == 'remote'
        Logging.log.info "Launching remote browser on port #{@config.get_config :global, :browser, :port}"
        capabilities = WebDriver::Remote::Capabilities.firefox(:javascript_enabled => true)
        @browser = Watir::Browser.new(:remote, :url => "http://127.0.0.1:#{@config.get_config :global, :browser, :port}/wd/hub", :desired_capabilities => capabilities)
      else
        Logging.log.info "Launching local browser"
        @browser = Watir::Browser.new :firefox
      end

      return @browser
    end
  end
end
