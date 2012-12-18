module Gless
  # Provides some wrapping around the normal Logger class.  In
  # particular, Gless::Logger has a concept of a replay log, which
  # is an attempt to lay out all the things that happened during its
  # interactions with the browser, including screenshots and HTML
  # source at each step.
  #
  # This does not improve performance.  :)
  #
  # It also tries to simplify the maintenance of multiple logging
  # streams, so that tests can be parallelized without too much
  # trouble.
  #
  # The core system creates a log object with the tag :master for
  # logging during setup and teardown.  It is expected that each
  # session object (i.e. each parallel browser instance) will create
  # its own for logging of what happens during the actual session.
  class Gless::Logger
    # The log stream that goes to STDOUT.  Here in case you need to
    # bypass the normal multi-log semantics.
    attr_reader :replay_log
    # The log stream that goes to the replay directory.  Here in
    # case you need to bypass the normal multi-log semantics.
    attr_reader :normal_log

    # Sets up logging.
    #
    # @param [Symbol] tag A short tag describing this particular log
    #   stream (as opposed to other parallel ones that might exist).
    #
    # @param [Boolean] replay Whether or not to generate a replay
    #   log as part of this log stream.
    #
    # @param [String] replay_path The path to put the replay logs
    #   in.  Passed through Kernel.sprintf with :home (ENV['HOME']),
    #   :tag, and :replay defined as you'd expect.
    def initialize( tag, replay = true, replay_path = '%{home}/public_html/watir_replay/%{tag}' )
      require 'logger'
      require 'fileutils'

      @ssnum = 0  # For snapshot pictures

      @replay_path=sprintf(replay_path, { :home => ENV['HOME'], :tag => tag, :replay => replay })
      FileUtils.rm_rf(@replay_path)
      FileUtils.mkdir(@replay_path)

      replay_log_file = File.open("#{@replay_path}/index.html", "w")
      @replay_log = ::Logger.new replay_log_file

      #@replay_log.formatter = proc do |severity, datetime, progname, msg|
      #  # I, [2012-08-14T15:30:10.736784 #14647]  INFO -- : <p>Launching remote browser</p>
      #  "<p>#{severity[0]}, [#{datetime} #{progname}]: #{severity} -- : #{msg}</p>\n"
      #end

      original_formatter = ::Logger::Formatter.new

      # Add in the tag and html-ify
      @replay_log.formatter = proc { |severity, datetime, progname, msg|
        # Can't flush after from here, so flush prior stuff
        replay_log_file.flush
        npn = "#{progname} #{tag} ".sub(/^\s*/,'').sub(/\s*$/,'')
        stuff=original_formatter.call(severity, datetime, "#{progname} #{tag} ", msg)
        #"<p>#{ERB::Util.html_escape(stuff.chomp)}</p>\n"
        "<p>#{stuff.chomp}</p>\n"
      }
      @replay_log.level = ::Logger::WARN

      @normal_log = ::Logger.new(STDOUT)
      # Add in the tag
      @normal_log.formatter = proc { |severity, datetime, progname, msg|
        original_formatter.call(severity, datetime, "#{progname} #{tag} ", msg)
      }

      @normal_log.level = ::Logger::WARN
    end

    # Passes on all the normal Logger methods.  By default, logs to
    # both the normal log and the replay log.
    def method_missing(m, *args, &block)
      @replay_log.send(m, *args, &block)
      @normal_log.send(m, *args, &block)
    end

    # Adds a screenshot and HTML source into the replay log from the
    # given browser.
    #
    # @param [Watir::Browser] browser
    # @param [Gless::Session] session
    def add_to_replay_log( browser, session )
      @ssnum = @ssnum + 1

      if session.get_config :global, :screenshots
      begin
        browser.driver.save_screenshot "#{@replay_path}/screenshot_#{@ssnum}.png"

        if session.get_config :global, :thumbnails
          require 'mini_magick'

          image = MiniMagick::Image.open("#{@replay_path}/screenshot_#{@ssnum}.png")
          image.resize "400"
          image.write "#{@replay_path}/screenshot_#{@ssnum}_thumb.png"
          FileUtils.chmod 0755, "#{@replay_path}/screenshot_#{@ssnum}_thumb.png"

          @replay_log.debug "Screenshot: <a href='screenshot_#{@ssnum}.png'><img src='screenshot_#{@ssnum}_thumb.png' /></a>"
        else
          @replay_log.debug "Screenshot: <a href='screenshot_#{@ssnum}.png'>Screenshot</a>"
        end
      rescue Exception => e
          @normal_log.warn "Screenshot failed with exception #{e}"
        end
      end

      html=browser.html
      htmlFile = File.new("#{@replay_path}/html_capture_#{@ssnum}.txt", "w")
      htmlFile.write(html)
      htmlFile.close

      @replay_log.debug "<a href='html_capture_#{@ssnum}.txt'>HTML Source</a>"
      @replay_log.debug "Force flush"
    end
  end
end
