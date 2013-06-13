require 'rspec'

module Gless
  #
  # This class is intended to be the base class for all page classes
  # used by the session object to represent individual pages on a
  # website.  In fact, if you *don't* subclass all your page classes
  # from this one, something is likely to break.
  #
  # = Class Level Methods
  #
  # This class defines a bunch of class-level behaviour, so that we can
  # have things like
  #
  #   element :email_field,       :text_field,    :id => 'email'
  #
  # in the class definition itself.
  #
  # However, this is too early to do much of the initialization,
  # which leads to some complexity in the real init method to
  # basically make up for deferred computation.
  #
  # = Calling Back To The Session
  #
  # The session object needs to know all of the page object classes.
  # This is accomplished by having an +inherited+ method on this
  # (the +BasePage+) class that calls +add_page_class+ on the Session
  # class; this only stores the subclass, it does no further
  # processing, since complicated processing at class creation time
  # tends to hit snags.  When a session object is actually
  # instantiated, the list of page classes is walked, and a page
  # class instance is created for each for future use.
  #
  class Gless::BasePage
    include RSpec::Matchers

    #******************************
    # Class Level
    #******************************

    class << self
      # @return [String] A URL that can be used to come to this page
      #   directly, if that can be known at compile time; has no
      #   sensible default
      attr_accessor :entry_url

      # @return [Array<String>, Array<Regexp>] A list of strings or
      #   patterns to add to the Session dispatch list
      attr_writer :url_patterns

      # @return [Array] Just sets up a default (to wit, []) for url_patterns
      def url_patterns
        @url_patterns ||= []
      end

      # Calls back to Gless::Session.  See overview documentation
      # for +Gless::BasePage+
      def inherited(klass)
        Gless::Session.add_page_class klass
      end

      # @return [Array<String>] An list of element method names that the page
      #   model contains.
      attr_writer :elements

      # @return [Array] Just sets up a default (to wit, []) for
      #   elements
      def elements
        @elements ||= []
      end

      # @return [Array<String>] An list of elements (actually just
      #   their method names) that should *always* exist if this
      #   page is loaded; used to wait for the page to load and
      #   validate correctness.  The page is not considered fully
      #   loaded until all of these elements are found.
      attr_writer :validator_elements

      # @return [Array] Just sets up a default (to wit, []) for
      #   validator_elements
      def validator_elements
        @validator_elements ||= []
      end

      # @return [Array<String>] An list of validator procedures for this page.
      #   This provides a more low-level version of validator elements.  For
      #   more information, see the documentation for +add_validator+.
      attr_writer :validator_blocks

      # @return [Array] Just sets up a default (to wit, []) for
      #   validator_blocks
      def validator_blocks
        @validator_blocks ||= []
      end

      # Specifies the title that this page is expected to have.
      #
      # @param [String,Regexp] expected_title
      def expected_title expected_title
        define_method 'has_expected_title?' do
          @session.log.debug "In GenericBasePage, for #{self.class.name}, has_expected_title?: current is #{@browser.title}, expected is #{expected_title}"
          expected_title.kind_of?(Regexp) ? @browser.title.should =~ expected_title :  @browser.title.should == expected_title
        end
      end

      # Specifies an element that might appear on the page.
      # The goal is to be easy for users of this library to use, so
      # there's some real complexity here so that the end user can
      # just do stuff like:
      #
      #   element :deleted_application    , :div     , :text => /Your application. \S+ has been deleted./
      # 
      # and it comes out feeling very natural.
      #
      # A longer example:
      #
      #   element :new_application_button , :element , :id => 'new_application'  , :validator => true , :click_destination => :ApplicationNewPage
      #
      # That's about as complicated as it gets.
      #
      # The first two arguments (name and type) are required.  The
      # rest is a hash.  +:validator+, +:click_destination+, +:parent+,
      # +:proc+, and +:cache+ (see below) have special meaning.
      #
      # Anything else is taken to be a Watir selector.  If no
      # selector is forthcoming, the name is taken to be the element
      # id.
      #
      # @param [Symbol] basename The name used in the Gless user's code
      #   to refer to this element.  This page object ends up with a
      #   method of this name.
      #
      # @param [Symbol] type The Watir element type; used to
      #   dynamically pick which Watir element class to use for this
      #   element.
      #
      # @param [Hash] opts Further options for the element.
      #
      # @option opts [Boolean] :validator (false) Whether or not the element should
      #   be used to routinely validate the page's correctness
      #   (i.e., if the element is central to the page and always
      #   reliably is present).  The page isn't considered loaded
      #   until all validator elements are present.  Defaults to
      #   false.
      #
      # @option opts [Symbol] :click_destination (nil) A symbol giving the last
      #   bit of the class name of the page that clicking on this
      #   element leads to, if any.
      # 
      # @option opts [Symbol] :parent (nil) A symbol of a parent element
      #   to which matching is restricted.
      # 
      # @option opts [Symbol] :cache (nil) If non-nil, overrides the default
      #   cache setting and determines whether caching is enabled for this
      #   element.  If false, a new look-up will be performed each time the
      #   element is accessed, and, if true, a look-up will only be performed
      #   once until the session changes the page.
      # 
      # @option opts [Symbol] :proc (nil) If present, specifies a manual,
      #   low-level procedure to return a watir element, which overrides other
      #   selectors.  When the watir element is needed, this procedure is
      #   called with the parent watir element passed as the argument (see
      #   +:parent+) if it exists, and otherwise the browser.
      # 
      # @option opts [Object] ANY All other opts keys are used as
      #   Watir selectors to find the element on the page.
      def element basename, type, opts = {}
        # No class-compile-time logging; it's way too much work, as this runs at *rake* time
        # $master_logger.debug "In GenericBasePage for #{self.name}: element: initial opts: #{opts}"

        # Promote various other things into selectors; do this before
        # we add in the default below
        non_selector_opts = [ :validator, :click_destination, :parent, :cache ]
        if ! opts[:selector]
          opts[:selector] = {} if ! opts.keys.empty?
          opts.keys.each do |key|
            if (! non_selector_opts.member?(key)) && (key != :selector)
              opts[:selector][key] = opts[key]
              opts.delete(key)
            end
          end
        end

        opts = { :selector => { :id => basename.to_s }, :validator => false, :click_destination => nil }.merge(opts)

        # No class-compile-time logging; it's way too much work, as this runs at *rake* time
        # $master_logger.debug "In GenericBasePage for #{self.name}: element: final opts: #{opts}"

        selector = opts[:selector]
        click_destination = opts[:click_destination]
        validator = opts[:validator]
        parent = opts[:parent]
        cache = opts[:cache]

        methname = basename.to_s.tr('-', '_').to_sym

        elements << methname
        if validator
          # No class-compile-time logging; it's way too much work, as this runs at *rake* time
          # $master_logger.debug "In GenericBasePage, for #{self.name}, element: #{basename} is a validator"
          validator_elements << methname
        end

        if click_destination
          # No class-compile-time logging; it's way too much work, as this runs at *rake* time
          # $master_logger.debug "In GenericBasePage, for #{self.name}, element: #{basename} has a special destination when clicked, #{click_destination}"
        end

        define_method methname do
          cached_elements[methname] ||= Gless::WrapWatir.new(methname, @browser, @session, self, type, selector, click_destination, parent, cache)
        end
      end

      # Adds the given block to the list of validators to this page, which is
      # run to ensure that the page is loaded.  This provides a low-level
      # version of validator elements, which has more flexibility in
      # determining whether the page is loaded.  The block is given two
      # arguments: the browser, and the session.  The block is expected to
      # return true if the validation succeeded; i.e., the page is currently
      # loaded according to the validator's test; and otherwise false.
      def add_validator &blk
        validator_blocks << blk
      end

      # @return [Rexexp,String] Used to give the URL string or pattern that matches this page; example:
      #
      #   url %r{^:base_url/accounts/[0-9]+/apps$}
      #
      # +:base_url+ is replaced with the output of
      # +@application.base_url+
      def url( url )
        if url.is_a?(String)
          url_patterns << Regexp.new(Regexp.escape(url))
        elsif url.is_a?(Regexp)
          url_patterns << url
        else
          puts "INVALID URL class "+url.class.name+" for #{url.inspect}"
        end
      end

      # Set this page's entry url.
      #
      # @param [String] url
      def set_entry_url( url )
        @entry_url = url
      end

    end # class-level definitions

    #******************************
    # Instance Level
    #******************************


    # @return [Watir::Browser]
    attr_accessor :browser

    # The main application object.  See the README for specifics.
    attr_accessor :application

    # @return [Gless::Session] The session object that uses/created
    #   this page.
    attr_accessor :session

    # Perform special variable substitution; used for url match
    # patterns and entry urls.
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
      # @session.log.debug "In GenericBasePage, for #{self.class.name}, init: #{browser}, #{session}, #{application}"
      @browser = browser
      @session = session
      @application = application

      # Couldn't do this any earlier, needed the application
      if self.class.entry_url
        self.class.entry_url = substitute self.class.entry_url 
      end

      # Fake inheritance time
      self.class.elements += self.class.ancestors.map { |x| x.respond_to?( :elements ) ? x.elements : nil }
      self.class.elements = self.class.elements.flatten.compact.uniq
      self.class.validator_elements += self.class.ancestors.map { |x| x.respond_to?( :validator_elements ) ? x.validator_elements : nil }
      self.class.validator_elements = self.class.validator_elements.flatten.compact.uniq

      self.class.url_patterns.map! { |x| substitute x }

      @session.log.debug "In GenericBasePage, for #{self.class.name}, init: class vars: #{self.class.entry_url}, #{self.class.url_patterns}, #{self.class.elements}, #{self.class.validator_elements}"
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
      @session.log.debug "#{self.class.name}: enter"

      raise "#{self.class.name}.enter: no entry_url has been set" if self.class.entry_url.nil?

      arrived? do
        @session.log.info "#{self.class.name}: about to goto #{self.class.entry_url} from #{@browser.url}"
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
              @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} found."
            else
              # Probably never reached
              @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} NOT found."
            end
          rescue Watir::Wait::TimeoutError => e
            @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: validator element #{x} NOT found."
            all_validate = false
          end
        end

        self.class.validator_blocks.each do |x|
          if ! x.call @browser, @session
            @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: a validator block failed."
            all_validate = false
          end
        end

        if all_validate
          if match_url( @browser.url )
            @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: all validator elements found."
            break
          else
            @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: all validator elements found, but the current URL (#{@browser.url}) doesn't match the expected URL(s) (#{self.class.url_patterns})"
          end
        else
          @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: not all validator elements found, trying again."
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

        @session.log.debug "In GenericBasePage, for #{self.class.name}, arrived?: completed successfully."
        return true
      rescue Exception => e
        if @session.get_config :global, :debug
          @session.log.debug "GenericBasePage, for #{self.class.name}, arrived?: something doesn't match (url or title or expected elements), exception information follows, then giving you a debugger"
          @session.log.debug "Gless::BasePage: Had an exception in debug mode: #{e.inspect}"
          @session.log.debug "Gless::BasePage: Had an exception in debug mode: #{e.message}"
          @session.log.debug "Gless::BasePage: Had an exception in debug mode: #{e.backtrace.join("\n")}"
          debugger
        else
          return false
        end
      end
    end

    #******************************
    # Object Level
    #******************************

    # @return [Hash] A hash of cached +WrapWatir+ elements indexed by the
    #   symbol name.  This hash is cleared whenever the page changes.
    attr_writer :cached_elements

    # @return [Hash] A hash of cached +WrapWatir+ elements indexed by the
    #   symbol name.  This hash is cleared whenever the page changes.
    def cached_elements
      @cached_elements ||= {}
    end
  end
end
