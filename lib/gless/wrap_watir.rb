
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
    include RSpec::Matchers

    # Sets up the wrapping.
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
      @elem = @browser.send(@orig_type, @orig_selector_args)
      @num_retries = 3
      @wait_time = 30
      @click_destination = click_destination
    end

    # Passes everything through to the underlying Watir object, but
    # with logging.
    def method_missing(m, *args, &block)
      wrapper_logging(m, args)
      @elem.send(m, *args, &block)
    end

    # Used to log all pass through behaviours.  In debug mode,
    # displays details about what method was passed through, and the
    # nature of the element in question.
    def wrapper_logging(m, args)
      if @orig_selector_args.inspect =~ /password/i
        @session.log.debug "WrapWatir: Doing something with passwords, redacted."
      else
        if @session.get_config :global, :debug
          @session.log.add_to_replay_log( @browser, @session )
        end

        @session.log.debug "WrapWatir: Calling #{m} with arguments #{args.inspect} on a #{@elem.class.name} element identified by: #{@orig_selector_args.inspect}"

        if @elem.present? && @elem.class.name == 'Watir::HTMLElement'
          @session.log.warn "FIXME: You have been lazy and said that something is of type 'element'; its actual type is  #{@elem.to_subtype.class.name}"
        end
      end
    end

    # A wrapper around Watir's click; handles the changing of
    # acceptable pages (i.e. click_destination processing, see
    # {Gless::BasePage} and {Gless::Session} for more details).
    def click
      if @click_destination
        @session.log.debug "WrapWatir: A #{@elem.class.name} element identified by: #{@orig_selector_args.inspect} has a special destination when clicked, #{@click_destination}"
        @session.acceptable_pages = @click_destination
      end
      wrapper_logging('click', nil)
      @session.log.debug "WrapWatir: Calling click on a #{@elem.class.name} element identified by: #{@orig_selector_args.inspect}"
      @elem.click
    end

    # Used by `set`, see description there.
    def set_retries!(retries)
      @num_retries=retries

      return self
    end

    # Used by `set`, see description there.
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

      # Double-check text fields
      if @elem.class.name == 'Watir::TextField'
        set_text = args[0]
        @elem.set(set_text)

        @num_retries.times do |x|
          @session.log.debug "WrapWatir: Checking that text entry worked"
          @elem = @browser.send(@orig_type, @orig_selector_args)
          if @elem.value == set_text
            break
          else
            @session.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            @session.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', set_text)
            @elem.set(set_text)
          end
        end
        @elem.value.should == set_text
        @session.log.debug "WrapWatir: The text entry worked"

        return self

        # Double-check radio buttons
      elsif @elem.class.name == 'Watir::Radio'
        wrapper_logging('set', [])
        @elem.set

        @num_retries.times do |x|
          @session.log.debug "WrapWatir: Checking that the radio selection worked"
          @elem = @browser.send(@orig_type, @orig_selector_args)
          if @elem.set? == true
            break
          else
            @session.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            @session.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', [])
            @elem.set
          end
        end
        @elem.set?.should be_true
        @session.log.debug "WrapWatir: The radio set worked"

        return self

      else
        @elem.set(*args)
      end
    end
  end
end
