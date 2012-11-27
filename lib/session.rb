
module Gless

  # FIXME: Document
  class Gless::Session
    include RSpec::Matchers

    attr_reader :current_page
    attr_reader :acceptable_pages

    def initialize( browser, application, page_base_class, start_page )
      Logging.log.debug "Session: Initializing with #{browser.inspect}"
      @browser = browser
      @application = application
      @pages = Hash.new
      @timeout = 30
      @page_base_class = page_base_class
      @start_page = start_page

      @page_base_class.subclasses.each do |sc|
        page = sc.new( @browser, self, @application )
        @pages[sc] = page
      end

      # Special case: add the login page, which isn't really part of
      # the application
      page = @start_page.new( @browser, self, @application )
      @pages[@start_page] = page

      # Logging.log.debug "Session: Final pages table: #{@pages.inspect}"
    end

    def session_logging(m, args)
      if m.inspect =~ /(password|login)/i or args.inspect =~ /(password|login)/i
        Logging.log.debug "Session: Doing something with passwords, redacted."
      else
        Logging.log.debug "Session: method_missing for #{m} with arguments #{args.inspect}"
      end
    end

    def enter(pklas)
      Logging.log.info "Session: Entering the site directly using the entry point for the #{pklas.name} page class"
      @current_page = pklas
      @acceptable_pages = pklas
      @pages[pklas].enter
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
        return [ @page_base_class.const_get(newpage) ]
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
      Logging.log.debug "Session: changing acceptable pages list to #{newpage}"
      @acceptable_pages = (check_acceptable_pages newpage).flatten
      Logging.log.info "Session: acceptable pages list has been changed to: #{@acceptable_pages}"
    end

    # By default, pick the right page and pass it on
    def method_missing(m, *args, &block)
      session_logging(m, args)

      Logging.log.debug "Session: check if we've changed pages: #{@browser.title}, #{@browser.url}, #{@previous_url}, #{@current_page}, #{@acceptable_pages}"

      # Changed URL means we've changed pages.  Our current page no
      # longer being in the acceptable pages list means we *should*
      # have changed pages. So we check both.
      if @browser.url == @previous_url && @acceptable_pages.member?( @current_page )
        Logging.log.debug "Session: doesn't look like we've moved."
      else
        # See if we're on one of the acceptable pages; wait until we
        # are for "timeout" seconds.
        good_page=false
        new_page=nil
        @timeout.times do
          @acceptable_pages.each do |page|
            Logging.log.debug "Session: Checking our current url, #{@browser.url}, for a match in #{page.name}: #{@pages[page].match_url(@browser.url)}"
            if @pages[page].match_url(@browser.url)
              good_page    = true
              @current_page = page
              new_page = @pages[page]
              Logging.log.debug "Session: we seem to be on #{page.name} at #{@browser.url}"
              break
            end
          end

          if good_page
            break
          end
          sleep 1
        end

        good_page.should be_true, "Current URL is #{@browser.url}, which doesn't match any of the acceptable pages: #{@acceptable_pages}"

        Logging.log.debug "Session: checking for arrival at #{new_page.class.name}"
        new_page.arrived?.should be_true

        url=@browser.url
        Logging.log.debug "Session: refreshed browser URL: #{url}"
        new_page.match_url(url).should be_true

        Logging.log.info "Session: We are currently on page #{new_page.class.name}, as we should be"

        @previous_url = url
      end

      cpage = @pages[@current_page]

      if m.inspect =~ /(password|login)/i or args.inspect =~ /(password|login)/i
        Logging.log.debug "Session: dispatching method #{m} with args [redacted; password maybe] to #{cpage}"
      else
        Logging.log.debug "Session: dispatching method #{m} with args #{args.inspect} to #{cpage}"
      end
      retval = cpage.send(m, *args, &block)
      Logging.log.debug "Session: method returned #{retval}"

      retval
    end
  end

end
