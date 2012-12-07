require 'logging'

module Gless
  class Gless::BasePage
    include RSpec::Matchers

    #******************************
    # Class Level
    #******************************
    #
    # We now define a bunch of class-level behaviour, so that we can
    # have things like
    #
    # element :email_field,       :text_field,    { :id => 'email' }, true
    #
    # in the class definition itself.
    #
    # However, this is too early to do much of the initialization,
    # which leads to some complexity in the real init method to
    # basically make up for deferred computation.
    #
    class << self
      # A URL that can be used to come to this page directly, if that
      # can be known at compile time; has no sensible default
      attr_accessor :entry_url

      # A list of strings or patterns to add to the Session dispatch
      # list
      attr_writer :url_patterns
      def url_patterns
        @url_patterns ||= []
      end

      # FIXME: document the hell out of this
      def inherited(klass)
        Gless::Session.add_page_class klass
      end

      # An element (well, name of an element) that should *always* exist
      # if this page is loaded; used to wait for the page to load and
      # validate correctness.  The page is not considered fully loaded
      # until all of these elements are found.
      attr_writer :validator_elements
      def validator_elements
        @validator_elements ||= []
      end

      def expected_title expected_title
        define_method 'has_expected_title?' do
          Logging.log.debug "In GenericBasePage, for #{self.class.name}, has_expected_title?: current is #{@browser.title}, expected is #{expected_title}"
          expected_title.kind_of?(Regexp) ? @browser.title.should =~ expected_title :  @browser.title.should == expected_title
        end
      end

      # The arguments here are our internal name for the field, the
      # Watir type/class of the element, a Watir selector hash, and
      # whether or not the element should be used to routinely validate
      # the page's correctness (i.e., if the element is central to the
      # page and always reliably is present).  The page isn't considered
      # loaded until all validator elements are present.
      def element basename, type, opts = {}
        Logging.log.debug "In GenericBasePage for #{self.name}: element: initial opts: #{opts}"

        # Promote various other things into selectors; do this before
        # we add in the default below
        non_selector_opts = [ :validator, :click_destination ]
        if ! opts[:selector]
          opts.keys.each do |key|
            if ! non_selector_opts.member?(key)
              opts[:selector] = { key => opts[key] }
              opts.delete(key)
            end
          end
        end

        opts = { :selector => { :id => basename.to_s }, :validator => false, :click_destination => nil }.merge(opts)

        Logging.log.debug "In GenericBasePage for #{self.name}: element: final opts: #{opts}"

        selector = opts[:selector]
        click_destination = opts[:click_destination]
        validator = opts[:validator]

        methname = basename.to_s.tr('-', '_')

        if validator
          Logging.log.debug "In GenericBasePage, for #{self.name}, element: #{basename} is a validator"
          validator_elements << methname
        end

        if click_destination
          Logging.log.debug "In GenericBasePage, for #{self.name}, element: #{basename} has a special destination when clicked, #{click_destination}"
        end

        define_method methname do
          WrapWatir.new(@browser, @session, type, selector, click_destination)
        end
      end

      def url( url )
        if url.is_a?(String)
          url_patterns << Regexp.new(Regexp.escape(url))
        elsif url.is_a?(Regexp)
          url_patterns << url
        else
          puts "INVALID URL class "+url.class.name+" for #{url.inspect}"
        end
      end

      # Variable substitution in the entry_url
      def set_entry_url( url )
        @entry_url = url
      end

    end # class-level definitions

    #******************************
    # Instance Level
    #******************************
    attr_accessor :browser
    attr_accessor :application
    attr_accessor :session

    # Perform special variable substitution
    def substitute str
      if str.kind_of?(Regexp)
        reg = str.source
        reg.gsub!(/\:base_url/,@application.base_url)
        return Regexp.new(reg)
      else
        return str.gsub(/\:base_url/,@application.base_url)
      end
    end

    def initialize browser, session, application
      # Logging.log.debug "In GenericBasePage, for #{self.class.name}, init: #{browser}, #{session}, #{application}"
      @browser = browser
      @session = session
      @application = application

      # Couldn't do this any earlier, needed the application
      if self.class.entry_url
        self.class.entry_url = substitute self.class.entry_url 
      end

      # Fake inheritance time
      self.class.validator_elements = self.class.validator_elements + self.class.ancestors.map { |x| x.respond_to?( :validator_elements ) ? x.validator_elements : nil }
      self.class.validator_elements = self.class.validator_elements.flatten.compact.uniq

      self.class.url_patterns.map! { |x| substitute x }

      Logging.log.debug "In GenericBasePage, for #{self.class.name}, init: class vars: #{self.class.entry_url}, #{self.class.url_patterns}, #{self.class.validator_elements}"
    end

    # Return true if the given url matches this page's patterns
    def match_url( url )
      self.class.url_patterns.each do |pattern|
        if url =~ pattern
          return true
        end
      end

      return false
    end

    # Pass through anything we don't understand to the browser, just
    # in case.
    def method_missing sym, *args, &block
      @browser.send sym, *args, &block
    end

    # Go to the page from who-cares-where, and make sure we're there
    def enter
      Logging.log.debug "#{self.class.name}: enter"

      arrived? do
        Logging.log.info "#{self.class.name}: about to goto #{self.class.entry_url} from #{@browser.url}"
        @browser.goto self.class.entry_url
      end
    end

    # Make sure that we've actually gotten to this page, after clicking a button or whatever; used by Session
    #
    # Takes an optional block; if that block exists, it's run before
    # the per-loop validation attempt.
    def arrived?
      all_validate = true

      6.times do
        if ! match_url( @browser.url )
          yield if block_given?
        end

        self.class.validator_elements.each do |x|
          begin
            if self.send(x).wait_until_present(5) 
              Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} found."
            else
              # Probably never reached
              Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} NOT found."
            end
          rescue Watir::Wait::TimeoutError => e
            Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} NOT found."
            all_validate = false
          end
        end

        if all_validate && match_url( @browser.url )
          Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: all validator elements found."
          break
        else
          Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: not all validator elements found, trying again."
        end
      end

      begin
        if respond_to? :has_expected_title?
          has_expected_title?.should be_true
        end

        match_url( @browser.url ).should be_true

        # We don't use all_validate here because we want to alert on the
        # element with the problem
        self.class.validator_elements.each do |x|
          self.send(x).wait_until_present(5).should be_true
        end

        Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: completed successfully."
        return true
      rescue Exception => e
        if @session.get_config :global, :debug
          Logging.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: something doesn't match (url or title or expected elements), giving you a debugger"
          debugger
        else
          return false
        end
      end
    end
  end
end
