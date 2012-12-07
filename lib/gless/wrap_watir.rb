
module Gless

  class Gless::WrapWatir
    include RSpec::Matchers

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
    def wrapper_logging(m, args)
      if @orig_selector_args.inspect =~ /password/i
        Logging.log.debug "WrapWatir: Doing something with passwords, redacted."
      else
        if @session.get_config :global, :debug
          Logging.add_to_replay_log( @browser, @session )
        end

        Logging.log.debug "WrapWatir: Calling #{m} with arguments #{args.inspect} on a #{@elem.class.name} element identified by: #{@orig_selector_args.inspect}"

        if @elem.present? && @elem.class.name == 'Watir::HTMLElement'
          Logging.log.warn "FIXME: You have been lazy and said that something is of type 'element'; its actual type is  #{@elem.to_subtype.class.name}"
        end
      end
    end

    def method_missing(m, *args, &block)
      wrapper_logging(m, args)
      @elem.send(m, *args, &block)
    end

    def click
      if @click_destination
        Logging.log.debug "WrapWatir: A #{@elem.class.name} element identified by: #{@orig_selector_args.inspect} has a special destination when clicked, #{@click_destination}"
        @session.acceptable_pages = @click_destination
      end
      wrapper_logging('click', nil)
      Logging.log.debug "WrapWatir: Calling click on a #{@elem.class.name} element identified by: #{@orig_selector_args.inspect}"
      @elem.click
    end

    def set_retries!(retries)
      @num_retries=retries

      return self
    end

    def set_timeout!(timeout)
      @wait_time=timeout

      return self
    end

    def set(*args)
      wrapper_logging('set', args)

      # Double-check text fields
      if @elem.class.name == 'Watir::TextField'
        set_text = args[0]
        @elem.set(set_text)

        @num_retries.times do |x|
          Logging.log.debug "WrapWatir: Checking that text entry worked"
          @elem = @browser.send(@orig_type, @orig_selector_args)
          if @elem.value == set_text
            break
          else
            Logging.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            Logging.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', set_text)
            @elem.set(set_text)
          end
        end
        @elem.value.should == set_text
        Logging.log.debug "WrapWatir: The text entry worked"

        return self

        # Double-check radio buttons
      elsif @elem.class.name == 'Watir::Radio'
        wrapper_logging('set', [])
        @elem.set

        @num_retries.times do |x|
          Logging.log.debug "WrapWatir: Checking that the radio selection worked"
          @elem = @browser.send(@orig_type, @orig_selector_args)
          if @elem.set? == true
            break
          else
            Logging.log.debug "WrapWatir: It did not; sleeping for #{@wait_time} seconds"
            sleep @wait_time
            Logging.log.debug "WrapWatir: Retrying."
            wrapper_logging('set', [])
            @elem.set
          end
        end
        @elem.set?.should be_true
        Logging.log.debug "WrapWatir: The radio set worked"

        return self

      else
        @elem.set(*args)
      end
    end
  end
end
