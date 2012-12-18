load 'lib/startup.rb'

require 'rspec/expectations'
World(RSpec::Matchers)
World(RSpec::Expectations)

Before do
  require 'gless'

  # FIXME: the tag entry here will have to change for parallel runs.
  @logger, @config, @browser = Gless.setup( :test )

  if @config.get :global, :debug
    require 'debugger'
  end
end

After do |scenario|
  if @config.get :global, :debug
    if scenario.failed?
      @logger.debug "Since you're in debug mode, and we've just failed out, here's a debugger. #1"
      debugger
    end
  else
    @browser.close
  end
end
