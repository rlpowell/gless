require 'watir-webdriver'

module Gless
  class Gless::Browser
    attr_reader :browsar

    def initialize( config )
      @config = config
      Logging.log.debug "Launching some browser; #{@config.get :global, :browser, :type}, #{@config.get :global, :browser, :port}"

      if (@config.get :global, :browser, :type) == 'remote'
        Logging.log.info "Launching remote browser on port #{@config.get :global, :browser, :port}"
        # Don't actually need this yet, not sure if it works, and it
        # adds a requirement of selenium-webdriver.
        #capabilities = Selenium::WebDriver::Remote::Capabilities.firefox(:javascript_enabled => true)
        @browser = Watir::Browser.new(:remote, :url => "http://127.0.0.1:#{@config.get :global, :browser, :port}/wd/hub") #, :desired_capabilities => capabilities)
      else
        Logging.log.info "Launching local browser"
        @browser = Watir::Browser.new :firefox
      end

      return @browser
    end

    def method_missing(m, *args, &block)
      @browser.send(m, *args, &block)
    end
  end
end
