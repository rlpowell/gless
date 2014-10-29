require 'uri'
require 'gless'

module TestGithub

  class TestGithub::Application
    include RSpec::Matchers

    attr_accessor :browser
    attr_accessor :session
    attr_accessor :site
    attr_accessor :base_url

    def initialize( browser, config, logger )
      @logger = logger
      
      @logger.debug "TestGithub Application: initializing with browser #{browser.inspect}"

      @browser = browser
      @config = config

      @base_url = @config.get :global, :site, :url
      @base_url.should be_truthy

      # Create the session
      @session = Gless::Session.new( @browser, @config, @logger, self )

      @session.should be_truthy

      @logger.info "TestGithub Application: going to github"
      @session.enter TestGithub::LoginPage
    end

    def goto_repository_from_anywhere name, repo_pattern
      @logger.info "TestGithub Application: going to repository #{name}"

      @session.enter TestGithub::SearchPage

      @session.search_for name

      repodata = @session.find_repository repo_pattern
      repodata.should be_truthy, "TestGithub Application: couldn't find repository #{name}"

      @logger.info "TestGithub Application: found repository #{repodata[:name]}, which was at number #{repodata[:index] + 1} on the page, now opening it."

      @session.goto_repository repo_pattern
    end

    def poke_headers
      @logger.info "TestGithub Application: trying out all the header buttons."

      @logger.info "TestGithub Application: clicking explore."
      @session.explore.click

      @logger.info "TestGithub Application: clicking features."
      @session.features.click

      @logger.info "TestGithub Application: clicking blog."
      @session.blog.click

      @logger.info "TestGithub Application: clicking home."
      @session.home.click
    end
  end
end
