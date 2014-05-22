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

      @logger.debug "Requested browser config: #{@config.get :global, :browser }"

      type=@config.get :global, :browser, :type
      browser=@config.get :global, :browser, :browser
      port=@config.get :global, :browser, :port
      url=@config.get_default false, :global, :browser, :url
      extra_capabilities=@config.get_default false, :global, :browser, :extras
      if ! extra_capabilities
        extra_capabilities = Hash.new
      end

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
        )
        # Load in any other stuff the user asked for
        @logger.debug "Requested extra capabilities: #{extra_capabilities.inspect}"
        extra_capabilities.each do |key, value|
          @logger.debug "Adding capability #{key} with value #{value}"
          capabilities[key] = value
        end

        if url
          @logger.debug "Launching with custom url #{url}"
        else
          url = "http://127.0.0.1:#{port}/wd/hub"
        end

        client = Selenium::WebDriver::Remote::Http::Default.new
        client.timeout = config.get_default( 600, :global, :browser, :timeout )

        @browser = Watir::Browser.new(:remote, :url => url, :desired_capabilities => capabilities, :http_client => client)
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
