Given %r{^I start the application$} do
  klass = @config.get :global, :site, :class
  @application = Object.const_get(klass)::Application.new( @browser, @config, @logger )
  @application.should be_truthy
end

When %r{^I fall through to the page object$} do
  @application.session.features.click
end

When 'I go to the Gless repo via the search page' do
  @application.goto_repository_from_anywhere 'gless', %r{^rlpowell\s*/\s*gless$}
end

When 'I poke lots of buttons' do
  @application.poke_headers
end

Then 'I am on the Gless repo page' do
  @application.session.arrived?.should be_truthy
  @application.browser.url.should == 'https://github.com/rlpowell/gless'
end

Then %r{^I am on the Features page$} do
  @application.browser.url.should == 'https://github.com/features/projects'
end

