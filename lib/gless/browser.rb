require 'watir-webdriver'
require 'selenium-webdriver'

module Gless
  # A very minor wrapper on the Watir::Browser class to use
  # Gless's config file system. Other than that it just adds logging
  # at this point.  It might do more later.
  class Gless::Browser
    # The underlying Watir::Browser
    attr_reader :browser

    # Takes a Gless::EnvConfig object, which it uses to
    # decide what kind of browser to launch, and launches a browser.
    #
    # @param [Gless::EnvConfig] config A Gless::EnvConfig which has
    #   :global => :browser => :type defined.
    #
    # @return [Gless::Browser]
    def initialize( config, logger )
      @config = config
      @logger = logger
      type=@config.get :global, :browser, :type
      browser=@config.get :global, :browser, :browser
      port=@config.get :global, :browser, :port
      url=@config.get_default false, :global, :browser, :url
      browser_version=@config.get_default '', :global, :browser, :version
      platform=@config.get_default :any, :global, :browser, :platform
      max_duration=@config.get_default 1800, :global, :browser, :max_duration
      idle_timeout=@config.get_default 90, :global, :browser, :idle_timeout

      if browser =~ %r{^\s*ie\s*$} or browser =~ %r{^\s*internet\s*_?\s*explorer\s*$}
        browser = 'internet explorer'
      end

      @logger.debug "Launching some browser; #{type}, #{port}, #{browser}"

      if type == 'remote'
        @logger.info "Launching remote browser #{browser} on port #{port}"
        capabilities = Selenium::WebDriver::Remote::Capabilities.new(
          :browser_name => browser,
          :javascript_enabled=>true,
          :css_selectors_enabled=>true,
          :takes_screenshot=>true,
          :'max-duration' => max_duration,
          :'idle-timeout' => idle_timeout,
          :version => browser_version,
          :platform => platform
        )

        if url
          @logger.debug "Launching with custom url #{url}"
        else
          url = "http://127.0.0.1:#{port}/wd/hub"
        end

        @browser = Watir::Browser.new(:remote, :url => url, :desired_capabilities => capabilities)
      else
        @logger.info "Launching local browser #{browser}"
        @browser = Watir::Browser.new browser
      end
    end

    # Pass everything else through to the Watir::Browser
    # underneath.
    def method_missing(m, *args, &block)
      @browser.send(m, *args, &block)
    end
  end
end
