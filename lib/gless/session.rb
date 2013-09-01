require 'rspec'

module Gless

  # Provides an abstraction layer between the individual pages of an
  # website and the high-level application layer, so that the
  # application layer doesn't have to know about what page it's on
  # or similar.
  #
  # For details, see the README.
  class Gless::Session
    include RSpec::Matchers

    # The page class for the page the session thinks we're currently
    # on.
    attr_reader :current_page

    # A list of page classes of pages that it's OK for us to be on.
    # Usually just one, but some site workflows might have more than
    # one thing that can happen when you click a button or whatever.
    #
    # When you assign a value here, a fair bit of processing is
    # done.  Most of the actual work is in check_acceptable_pages
    #
    # The user can give us a class, a symbol, or a list of those; no
    # matter what, we return a list.  That list is of possible pages
    # that, if we turn out to be on one of them, that's OK, and if
    # not we freak out.
    #
    # @param [Class, Symbol, Array] newpages A page class, or a
    #   symbol naming a page class, or an array of those, for which
    #   pages are acceptable.
    attr_reader :acceptable_pages

    # See docs for :acceptable_pages
    def acceptable_pages= newpage
      log.debug "Session: changing acceptable pages list to #{newpage}"
      @acceptable_pages = (check_acceptable_pages newpage).flatten
      log.info "Session: acceptable pages list has been changed to: #{@acceptable_pages}"
    end

    # This exists only to be called by +inherited+ on
    # Gless::BasePage; see documentation there.
    def self.add_page_class( klass )
      @@page_classes ||= []
      @@page_classes << klass
    end


    # Sets up the session object.  As the core abstraction layer that
    # sits in the middle of everything, this requires a number of
    # arguments. :)
    #
    # @param [Gless::Browser] browser
    # @param [Gless::EnvConfig] config
    # @param [Gless::Logger] logger
    # @param [Object] application See the README for a description
    #   of the stuff the application object is expected to have.
    def initialize( browser, config, logger, application )
      @logger = logger

      log.debug "Session: Initializing with #{browser.inspect}"

      @browser = browser
      @application = application
      @pages = Hash.new
      @timeout = 30
      @acceptable_pages = nil
      @config = config

      @@page_classes.each do |sc|
        @pages[sc] = sc.new( @browser, self, @application )
      end

      log.debug "Session: Final pages table: #{@pages.keys.map { |x| x.name }}"

      return self
    end

    # Just passes through to the Gless::EnvConfig component's +get+
    # method.
    def get_config(*args)
      @config.get(*args)
    end

    # Just passes through to the Gless::EnvConfig component's +get_default+
    # method.
    def get_config_default(*args)
      @config.get_default(*args)
    end

    # Just a shortcut to get to the Gless::Logger object.
    def log
      @logger
    end

    # Anything that we don't otherwise recognize is passed on to the
    # current underlying page object (i.e. descendant of
    # Gless::BasePage).
    #
    # This gets complicated because of the state checking: we test
    # extensively that we're on the page that we think we should be
    # on before passing things on to the page object.
    def method_missing(m, *args, &block)
      # Do some logging.
      if m.inspect =~ /(password|login)/i or args.inspect =~ /(password|login)/i
        log.debug "Session: Doing something with passwords, redacted."
      else
        log.debug "Session: method_missing for #{m} with arguments #{args.inspect}"
      end

      log.debug "Session: check if we've changed pages: #{@browser.title}, #{@browser.url}, #{@previous_url}, #{@current_page}, #{@acceptable_pages}"

      # Changed URL means we've changed pages, probably by surprise
      # since desired page changes happen in Gless::WrapWatir#click
      if @browser.url == @previous_url
        log.debug "Session: doesn't look like we've moved."
      else
        # See if we're on one of the acceptable pages.  We do no
        # significant waiting because Gless::WrapWatir#click should
        # have handeled that.
        good_page=false
        new_page=nil
        if @acceptable_pages.nil?
          # If we haven't gone anywhere yet, anything is good
          good_page = true
          new_page = @pages[@current_page]
        else
          @acceptable_pages.each do |page|
            log.debug "Session: Checking our current url, #{@browser.url}, for a match in #{page.name}: #{@pages[page].match_url(@browser.url)}"
            if @pages[page].match_url(@browser.url)
              clear_cache
              good_page    = true
              @current_page = page
              new_page = @pages[page]
              log.debug "Session: we seem to be on #{page.name} at #{@browser.url}"
            end
          end
        end

        good_page.should be_true, "Current URL is #{@browser.url}, which doesn't match any of the acceptable pages: #{@acceptable_pages}"

        # While this is very thorough, it slows things down quite a
        # bit, and should mostly be covered by
        # Gless::WrapWatir#click ; leaving here in case we decide we
        # need it later.
        #
        # log.debug "Session: checking for arrival at #{new_page.class.name}"
        # new_page.arrived?.should be_true

        url=@browser.url
        log.debug "Session: refreshed browser URL: #{url}"
        new_page.match_url(url).should be_true

        log.info "Session: We are currently on page #{new_page.class.name}, as we should be"

        @previous_url = url
      end

      # End of page checking code.

      cpage = @pages[@current_page]

      if m.inspect =~ /(password|login)/i or args.inspect =~ /(password|login)/i
        log.debug "Session: dispatching method #{m} with args [redacted; password maybe] to #{cpage}"
      else
        log.debug "Session: dispatching method #{m} with args #{args.inspect} to #{cpage}"
      end
      retval = cpage.send(m, *args, &block)
      log.debug "Session: method returned #{retval}"

      retval
    end

    # This function is used to go to an intitial entry point for a
    # website.  The page in question must have had set_entry_url run
    # in its class definition, to define how to do this.  This setup
    # exists because explaining to the session that we really should
    # be on that page is a bit tricky.
    #
    # @param [Class] pklas The class for the page object that has a
    #   set_entry_url that we are using.
    # @param [Boolean] always (true) Whether to enter the given page even
    def enter(pklas, always = true)
      log.info "Session: Entering the site directly using the entry point for the #{pklas.name} page class"

      if always || pklas != @current_page
        @current_page = pklas
        @pages[pklas].enter
        # Needs to run through our custom acceptable_pages= method
        self.acceptable_pages = pklas
      else
        log.debug "Session: Already on page"
      end
    end

    # Wait for long-term AJAX-style processing, i.e. watch the page
    # for extended amounts of time until particular events have
    # occured.
    #
    # @param [String] message The text to print to the user each
    #   time the page is not completely loaded.
    # @param [Hash] opts Various named options.
    #
    # @option opts [Integer] numtimes The number of times to test the page.
    # @option opts [Integer] interval The number of seconds to delay
    #   between each check.
    # @option opts [Array] any_elements Watir page elements, if any
    #   of them are present, the page load is considered complete.
    # @option opts all_elements Watir page elements, if all of them
    #   are present, the page load is considered complete.
    #
    # @yieldreturn [Boolean] An optional Proc/code block; if
    #   present, it is run before each page check.  This is so
    #   simple interactions can occur without waiting for the
    #   timeout, and so the whole process can be short-circuited.
    #   If the block returns true, the long_wait ends successfully.
    #
    # @example
    #
    #   @session.long_wait "Cloud Application: Still waiting for the environment to be deleted.", :any_elements => [ @session.no_environments, @session.environment_deleted ]
    #
    # @return [Boolean] Returns true if, on any page test, the
    #   element conditions were met or the block returned true (at
    #   which point it exits immediately), false otherwise.
    def long_wait message, opts = {}
      # Merge in the defaults
      opts = { :numtimes => 120, :interval => 30, :any_elements => nil, :all_elements => nil }.merge(opts)

      begin
        opts[:numtimes].times do |count|
          # Run a code block if given; might do other checks, or
          # click things we need to finish, or whatever
          if block_given?
            self.log.debug "Session: long_wait: yielding to passed block."
            blockout = yield
            if blockout == true
              return true
            end
          end

          # If any of these are present, we're done.
          if opts[:any_elements]
            opts[:any_elements].each do |elem|
              self.log.debug "Session: long_wait: in any_elements, looking for #{elem}"
              if elem.present?
                self.log.debug "Session: long_wait: completed due to the presence of #{elem}"
                return true
              end
            end
          end
          # If all of these are present, we're done.
          if opts[:all_elements]
            all_elems=true
            opts[:all_elements].each do |elem|
              self.log.debug "Session: long_wait: in all_elements, looking for #{elem}"
              if ! elem.present?
                all_elems=false
              end
            end
            if all_elems == true
              self.log.debug "Session: long_wait: completed due to the presence of all off #{opts[:all_elements]}"
              return true
            end
          end

          # We're still here, let the user know
          self.log.info message

          if (((count + 1) % 20) == 0) && (self.get_config :global, :debug)
            self.log.debug "Session: long_wait: We've waited a multiple of 20 times, so giving you a debugger; 'c' to continue."
            debugger
          end

          sleep opts[:interval]
        end
      rescue Exception => e
        self.log.warn "Session: long_wait: Had an exception #{e}"
        if self.get_config :global, :debug
          self.log.debug "Session: long_wait: Had an exception in debug mode: #{e.inspect}"
          self.log.debug "Session: long_wait: Had an exception in debug mode: #{e.message}"
          self.log.debug "Session: long_wait: Had an exception in debug mode: #{e.backtrace.join("\n")}"

          self.log.debug "Session: long_wait: Had an exception, and you're in debug mode, so giving you a debugger.  Use 'continue' to proceed."
          debugger
        end

        self.log.debug "Session: long_wait: Retrying after exception."
        retry
      end

      return false
    end

    # Deals with popup alerts in the browser (i.e. the javascript
    # alert() function).  Always clicks "ok" or equivalent.
    # 
    # Note that we're using @browser because things can be a bit
    # wonky during an alert; we don't want to run session's "are we
    # on the right page?" tests, or even talk to the page object.
    #
    # @param [Boolean] wait_for_alert (true) Whether to wait until an alert
    # is present, failing if the request times out, before processing it;
    # otherwise, handle any alerts if there are any currently present.
    #
    # @param [String,Regexp] expected_text (nil) If not nil, the text of the
    # pop-up alert is checked against this parameter; if it
    # differs, an exception will be raised.
    def handle_alert wait_for_alert = true, expected_text = nil
      @browser.alert.wait_until_present if wait_for_alert

      if @browser.alert.exists?
        begin
          if expected_text
            current_text = @browser.alert.text
            if (expected_text.kind_of? Regexp) ? expected_text !~ current_text : expected_text != current_text
              msg = "The actual alert text differs from what was expected.  current_text: #{current_text}; expected_text: #{expected_text}"
              @logger.error msg
              raise msg
            end
          end

          @browser.alert.ok
        rescue Selenium::WebDriver::Error::NoAlertPresentError => e
          msg = "Alert no longer exists; likely closed by user: #{e.message}"
          if wait_for_alert
            @logger.warn msg
            raise
          else
            @logger.info msg
          end
        end
      end
    end

    # Clears the cached elements.  Used before each page change.
    #
    # @param [Class] page_class The page class of the page whose cached
    #   elements are to be cleared; defaults to the current page.
    def clear_cache page_class = nil
      @pages[page_class || current_page].cached_elements = Hash.new
    end

    # Does the heavy lifting, such as it is, for +acceptable_pages=+
    #
    # @param [Class, Symbol, Array] newpage A page class, or a
    #   symbol naming a page class, or an array of those, for which
    #   pages are acceptable.
    #
    # @return [Array<Gless::BasePage>]
    def check_acceptable_pages newpage
      if newpage.kind_of? Class
        return [ newpage ]
      elsif newpage.kind_of? Symbol
        return [ @pages.keys.find { |x| x.name =~ /#{newpage.to_s}$/ } ]
      elsif newpage.kind_of? Array
        return newpage.map { |p| check_acceptable_pages p }
      else
        raise "You set the acceptable_pages to #{newpage.class.name}; unhandled"
      end
    end

    # Does the heavy lifting of moving between pages when an element
    # has a new page destination.  Mostly used by Gless::WrapWatir
    #
    # Note that this attempts to click on the button (or do whatever
    # else the passed block does) many times in an attempt to get to
    # the right page.  If multiple attempts are a problem, you
    # should circumvent this method; {WrapWatir#click_once} exists
    # for this purpose.
    #
    # @param [Class, Symbol, Array] newpage The page(s) that we
    #   could be moving to; same idea as {acceptable_pages=}
    #
    # @yield A required Proc/code block that contains the action to
    #   take to attempt to change pages (i.e. clicking on a button
    #   or whatever).  May be run multiple times, as the whole point
    #   here is to keep trying until it works.
    #
    # @return (Boolean, String) Returns both whether it managed to
    #   get to the page in question and, if not, what sort of errors
    #   were seen.
    def change_pages click_destination
      self.acceptable_pages = click_destination

      log.debug "Session: change_pages: checking to see if we have changed pages: #{@browser.title}, #{@current_page}, #{@acceptable_pages}"

      good_page = false
      error_message = ''
      new_page = nil

      # See if we're on one of the acceptable pages; wait until we
      # are for "timeout" seconds.
      @timeout.times do
        self.log.debug "Session: change_pages: yielding to passed block."
        begin
          yield
        rescue Watir::Exception::UnknownObjectException => e
          error_message = "Caught UnknownObjectExepction; are the validators for #{@acceptable_pages} correct?  #{e.inspect}"
          log.warn "Session#change_pages: #{error_message}"
        end
        self.log.debug "Session: change_pages: done yielding to passed block."

        if @acceptable_pages.member?( @current_page )
          good_page = true
          new_page = @current_page
          break
        else
          new_page = nil

          if @acceptable_pages.nil?
            # If we haven't gone anywhere yet, anything is good
            log.debug "Session: change_pages: no acceptable pages, so accepting the current page."
            good_page    = true
            new_page = @pages[@current_page]
            break
          end

          url=@browser.url
          log.debug "Session: change_pages: refreshed browser URL: #{url}"

          @acceptable_pages.each do |page|
            log.debug "Session: change_pages: Checking our current url, #{url}, for a match in #{page.name}: #{@pages[page].match_url(url)}"
            if @pages[page].match_url(url) and @pages[page].arrived? == true
              clear_cache
              good_page    = true
              @current_page = page
              new_page = @pages[page]
              log.debug "Session: change_pages: we seem to be on #{page.name} at #{url}"
            end
          end

          if new_page
            if not new_page.match_url(url)
              good_page = false
              error_message = "Current URL is #{url}, which doesn't match that expected for any of the acceptable pages: #{@acceptable_pages}"
              next
            end

            log.debug "Session: change_pages: checking for arrival at #{new_page.class.name}"
            if not new_page.arrived?
              good_page = false
              error_message = "The current page, at #{url}, doesn't have all of the elements for any of the acceptable pages: #{@acceptable_pages}"
              next
            end
          end

          if good_page == true
            break
          else
            sleep 1
          end
        end
      end

      if good_page
        log.info "Session: change_pages: We have successfully moved to page #{new_page.class.name}"

        @previous_url = url
      else
        # Timed out.
        error_message = "Session: change_pages: attempt to change pages to #{click_destination} timed out after #{@timeout} tries.  Are the validators for #{@acceptable_pages} correct?"
      end

      return good_page, error_message
    end

  end

end
