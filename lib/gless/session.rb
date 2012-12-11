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
    attr_reader :acceptable_pages

    # This exists only to be called by +inherited+ on
    # Gless::BasePage; see documentation there.
    def self.add_page_class( klass )
      @@page_classes ||= []
      @@page_classes << klass
    end


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

    def get_config(*args)
      @config.get(*args)
    end

    def log
      @logger
    end

    def session_logging(m, args)
      if m.inspect =~ /(password|login)/i or args.inspect =~ /(password|login)/i
        log.debug "Session: Doing something with passwords, redacted."
      else
        log.debug "Session: method_missing for #{m} with arguments #{args.inspect}"
      end
    end

    def enter(pklas)
      log.info "Session: Entering the site directly using the entry point for the #{pklas.name} page class"
      @current_page = pklas
      @pages[pklas].enter
      # Needs to run through our custom acceptable_pages= method
      self.acceptable_pages = pklas
    end

    # FIXME: Check the text of the alert to see that it's the one
    # we want.
    # 
    # Note that we're using @browser because things can be a bit
    # wonky during an alert; we don't want to run session's "are we
    # on the right page?" tests, or even talk to the page object.
    def handle_alert
      @browser.alert.wait_until_present

      if @browser.alert.exists?
        @browser.alert.ok
      end
    end

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

    # Handle the user changing what page we're on.  Most of the work
    # is in check_acceptable_pages
    #
    # The user can give us a class, a symbol, or a list of those; no
    # matter what, we return a list.  That list is of possible pages
    # that, if we turn out to be on one of them, that's OK, and if
    # not we freak out.
    #
    def acceptable_pages=(newpage)
      log.debug "Session: changing acceptable pages list to #{newpage}"
      @acceptable_pages = (check_acceptable_pages newpage).flatten
      log.info "Session: acceptable pages list has been changed to: #{@acceptable_pages}"
    end

    # By default, pick the right page and pass it on
    def method_missing(m, *args, &block)
      session_logging(m, args)

      log.debug "Session: check if we've changed pages: #{@browser.title}, #{@browser.url}, #{@previous_url}, #{@current_page}, #{@acceptable_pages}"

      # Changed URL means we've changed pages.  Our current page no
      # longer being in the acceptable pages list means we *should*
      # have changed pages. So we check both.
      if @browser.url == @previous_url && @acceptable_pages.member?( @current_page )
        log.debug "Session: doesn't look like we've moved."
      else
        # See if we're on one of the acceptable pages; wait until we
        # are for "timeout" seconds.
        good_page=false
        new_page=nil
        @timeout.times do
          if @acceptable_pages.nil?
            # If we haven't gone anywhere yet, anything is good
            good_page = true
            new_page = @pages[@current_page]
            break
          end

          @acceptable_pages.each do |page|
            log.debug "Session: Checking our current url, #{@browser.url}, for a match in #{page.name}: #{@pages[page].match_url(@browser.url)}"
            if @pages[page].match_url(@browser.url)
              good_page    = true
              @current_page = page
              new_page = @pages[page]
              log.debug "Session: we seem to be on #{page.name} at #{@browser.url}"
              break
            end
          end

          if good_page
            break
          end
          sleep 1
        end

        good_page.should be_true, "Current URL is #{@browser.url}, which doesn't match any of the acceptable pages: #{@acceptable_pages}"

        log.debug "Session: checking for arrival at #{new_page.class.name}"
        new_page.arrived?.should be_true

        url=@browser.url
        log.debug "Session: refreshed browser URL: #{url}"
        new_page.match_url(url).should be_true

        log.info "Session: We are currently on page #{new_page.class.name}, as we should be"

        @previous_url = url
      end

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
  end

end
