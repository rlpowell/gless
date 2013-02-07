
module Gless

  # This class, as its name sort of implies, is used to wrap Watir
  # elements.  Every element on a Gless page (i.e. any descentant of
  # Gless::BasePage that uses the "element" class mothed) is not
  # actually a Watir element but rather a Gless::WrapWatir instead.
  #
  # Most things are passed through to the underlying Watir element,
  # but extensive logging occurs (in fact, if you have debugging on,
  # this is where screenshots occur), and various extremely
  # low-level checks are done to try to work around potential
  # Selenium problems.  For example, all text entry is checked at
  # this level and retried until it works, since Selenium/WebDriver
  # tends to be flaky about that (and it's even worse if the browser
  # window gets focus during the text entry).
  #
  # This shouldn't ever need to be used by a user; it's done
  # automatically by the +element+ class method.
  class Gless::WrapWatir
    require 'rspec'
    include RSpec::Matchers

    # Sets up the wrapping.
    #
    # As a special case, note that the selectors can include a :proc
    # element, in which case this is taken to be a Proc that takes
    # the browser as an argument.  This is used for cases where
    # finding the element has to happen at runtime or is
    # particularily complicated.  In this case the rest of the
    # selectors should include notes the element for debugging
    # purposes.  An example of such an element:
    #
    #    Gless::WrapWatir.new(@browser, @session, :input, { :custom => "the first input under the div for tab #{tab} with the id 'task_name'", :proc => Proc.new { |browser| browser.div( :id  => "tabs-#{tab}" ).input( :id => 'task_name' ) } }, false )
    #
    # The wrapper only considers *visible* matching elements, unless
    # the selectors include ":invisible => true".
    #
    # @param [Gless::Browser] browser
    # @param [Gless::Session] session
    # @param [Symbol] orig_type The type of the element; normally
    #   with watir you'd do something like
    #
    #     watir.button :value, 'Submit'
    #
    #   In that expression, "button" is the orig_type.
    # @param [Hash] orig_selector_args In the example
    #   above,
    #
    #     { :value => 'Submit' }
    #
    #   is the selector arguments.
    # @param [Gless::BasePage, Array<Gless::BasePage>] click_destination Optional. A list of pages that are OK places to end up after we click on this element
    def initialize(browser, session, orig_type, orig_selector_args, click_destination)
      @browser = browser
      @session = session
      @orig_type = orig_type
      @orig_selector_args = orig_selector_args
      @num_retries = 3
      @wait_time = 30
      @click_destination = click_destination
    end

    # Finds the element in question; deals with the fact that the
    # selector could actually be a Proc.
    #
    # Has no parameters because it uses @orig_type and
    # @orig_selector_args.  If @orig_selector_args has a :proc
    # element, runs that with the browser as an argument, otherwise
    # just passes those variables to the Watir browser as normal.
    def find_elem
      tries=0
      begin
        # Do we want to return more than on element?
        multiples = false

        if @orig_selector_args.has_key? :proc
          # If it's a Proc, it can handle its own visibility checking
          return @orig_selector_args[:proc].call @browser
        else
          # We want all the relevant elements, so force that if it's
          # not what was asked for
          type = @orig_type.to_s
          if type =~ %r{s$}
            multiples=true
          else
            if Watir::Container.method_defined?(type + 's')
              type = type + 's'
            elsif Watir::Container.method_defined?(type + 'es')
              type = type + 'es'
            end
          end
          @session.log.debug "WrapWatir: find_elem: elements type: #{type}"
          elems = @browser.send(type, @orig_selector_args)
        end

        @session.log.debug "WrapWatir: find_elem: elements identified by #{trimmed_selectors.inspect} initial version: #{elems.inspect}"

        if elems.nil? or elems.length == 0
          @session.log.debug "WrapWatir: find_elem: can't find any element identified by #{trimmed_selectors.inspect}"
          # Generally, watir-webdriver code expects *something*
          # back, and uses .present? to see if it's really there, so
          # we get the singleton to satisfy that need.
          return @browser.send(@orig_type, @orig_selector_args)
        end

        # We got something unexpected; just give it back
        if ! elems.is_a?(Watir::ElementCollection)
          @session.log.debug "WrapWatir: find_elem: elements aren't a collection; returning them"
          return elems
        end

        if multiples
          # We're OK returning the whole set
          @session.log.debug "WrapWatir: find_elem: multiples were requested; returning #{elems.inspect}"
          return elems
        elsif elems.length == 1
          # It's not a collection; just return it.
          @session.log.debug "WrapWatir: find_elem: only one item found; returning #{elems[0].inspect}"
          return elems[0]
        else
          unless @orig_selector_args.has_key? :invisible and @orig_selector_args[:invisible]
            if trimmed_selectors.inspect !~ /password/i
              @session.log.debug "WrapWatir: find_elem: elements identified by #{trimmed_selectors.inspect} before visibility selection: #{elems.inspect}"
            end

            # Find only visible elements
            elem = elems.find { |x| x.present? and x.visible? }

            if elem.nil?
              # If there *are* no visible ones, take what we've got
              elem = elems[0]
            end

            if trimmed_selectors.inspect !~ /password/i
              @session.log.debug "WrapWatir: find_elem: element identified by #{trimmed_selectors.inspect} after visibility selection: #{elem.inspect}"
            end

            return elem
          end
        end
      rescue Exception => e
        @session.log.warn "WrapWatir: find_elem: Had an exception #{e}"
        if @session.get_config :global, :debug
          @session.log.debug "WrapWatir: find_elem: Had an exception in debug mode: #{e.inspect}"
          @session.log.debug "WrapWatir: find_elem: Had an exception in debug mode: #{e.message}"
          @session.log.debug "WrapWatir: find_elem: Had an exception in debug mode: #{e.backtrace.join("\n")}"

          @session.log.debug "WrapWatir: find_elem: Had an exception, and you're in debug mode, so giving you a debugger. Use 'continue' to proceed."
          debugger
        end

        if tries < 3
          @session.log.debug "WrapWatir: find_elem: Retrying after exception."
          retry
        else
          @session.log.debug "WrapWatir: find_elem: Giving up after exception."
        end
        tries += 1
      end
    end

    # Pulls any procs out of the selectors for debugging purposes
    def trimmed_selectors
      @orig_selector_args.reject { |k,v| k == :proc }
    end

    # Passes everything through to the underlying Watir object, but
    # with logging.
    def method_missing(m, *args, &block)
      wrapper_logging(m, args)
      find_elem.send(m, *args, &block)
    end

    # Used to log all pass through behaviours.  In debug mode,
    # displays details about what method was passed through, and the
    # nature of the element in question.
    def wrapper_logging(m, args)
      elem = find_elem

      if trimmed_selectors.inspect =~ /password/i
        @session.log.debug "WrapWatir: Doing something with passwords, redacted."
      else
        if @session.get_config :global, :debug
          @session.log.add_to_replay_log( @browser, @session )
        end

        @session.log.debug "WrapWatir: Calling #{m} with arguments #{args.inspect} on a #{elem.class.name} element identified by: #{trimmed_selectors.inspect}"

        if elem.present? && elem.class.name == 'Watir::HTMLElement'
          @session.log.warn "FIXME: You have been lazy and said that something is of type 'element'; its actual type is  #{elem.to_subtype.class.name}; the element is identified by #{trimmed_selectors.inspect}"
        end
      end
    end

    # A wrapper around Watir's click; handles the changing of
    # acceptable pages (i.e. click_destination processing, see
    # {Gless::BasePage} and {Gless::Session} for more details).
    #
    # Unconditionally clicks once, without any error handling; if
    # you want to try to execute a page transition no matter what,
    # just use +click+
    def click_once
      elem = find_elem

      if @click_destination
        @session.log.debug "WrapWatir: A #{elem.class.name} element identified by: #{trimmed_selectors.inspect} has a special destination when clicked, #{@click_destination}"
        @session.acceptable_pages = @click_destination
      end
      wrapper_logging('click', nil)
      @session.log.debug "WrapWatir: Calling click on a #{elem.class.name} element identified by: #{trimmed_selectors.inspect}"
      elem.click
    end

    # A wrapper around Watir's click; handles the changing of
    # acceptable pages (i.e. click_destination processing, see
    # {Gless::BasePage} and {Gless::Session} for more details).
    #
    # If you've clicked on an element with a click_destination, it
    # then calls {Gless::Session#change_pages} to do the actual page
    # transition.  As such, it may actually click several times,
    # it will keep trying until it works; if that's not what you're
    # looking for, use click_once
    def click
      elem = find_elem

      if @click_destination
        @session.log.debug "WrapWatir: click: A #{elem.class.name} element identified by: #{trimmed_selectors.inspect} has a special destination when clicked, #{@click_destination}"
        change_pages_out, change_pages_message = @session.change_pages( @click_destination ) do
          wrapper_logging('click', nil)
          @session.log.debug "WrapWatir: click: Calling click on a #{elem.class.name} element identified by: #{trimmed_selectors.inspect}"
          if elem.exists?
            elem.click
          end
          if block_given?
            yield
          end
        end
        # If the return value isn't true, use it as the message to
        # print.
        @session.log.debug "WrapWatir: click: change pages results: #{change_pages_out}, #{change_pages_message}"
        change_pages_out.should be_true, change_pages_message
      else
        wrapper_logging('click', nil)
        @session.log.debug "WrapWatir: click: Calling click on a #{elem.class.name} element identified by: #{trimmed_selectors.inspect}"
        elem.click
      end
    end

    # Used by +set+, see description there.
    def set_retries!(retries)
      @num_retries=retries

      return self
    end

    # Used by +set+, see description there.
    def set_timeout!(timeout)
      @wait_time=timeout

      return self
    end

    # A wrapper around Watir's set element that retries operations.
    # In particular, text fields and radio elements are checked to
    # make sure that what we intended to enter *actually* got
    # entered.  set_retries! and set_timeout! set the number of
    # times to try to get things working and the delay between ecah
    # such try.
    def set(*args)
      wrapper_logging('set', args)
      elem = find_elem

      # Double-check text fields
      if elem.class.name == 'Watir::TextField'
        set_text = args[0]
        @session.log.debug "WrapWatir: set: setting text on #{elem.inspect}/#{elem.html} to #{set_text}"
        elem.set(set_text)

        @num_retries.times do |x|
          @session.log.debug "WrapWatir: Checking that text entry worked"
          if elem.value == set_text
            break
          else
            @session.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            @session.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', set_text)
            elem.set(set_text)
          end
        end
        elem.value.to_s.should == set_text.to_s
        @session.log.debug "WrapWatir: The text entry worked"

        return self

        # Double-check radio buttons
      elsif elem.class.name == 'Watir::Radio'
        wrapper_logging('set', [])
        elem.set

        @num_retries.times do |x|
          @session.log.debug "WrapWatir: Checking that the radio selection worked"
          if elem.set? == true
            break
          else
            @session.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            @session.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', [])
            elem.set
          end
        end
        elem.set?.should be_true
        @session.log.debug "WrapWatir: The radio set worked"

        return self

      else
        elem.set(*args)
      end
    end
  end
end
