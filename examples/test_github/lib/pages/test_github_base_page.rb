module TestGithub
  class TestGithub::BasePage < Gless::BasePage

    element :home     , :link , :href => %r{^(https://github.com|)/?$}          , :validator => true , :click_destination => :LoginPage
    element :explore  , :link , :href => %r{^(https://github.com|)/explore/?$}  , :validator => true , :click_destination => :ExplorePage
    element :features , :link , :href => %r{^(https://github.com|)/features/?$} , :validator => true , :click_destination => :FeaturesPage
    element :blog     , :link , :href => %r{^(https://github.com|)/blog/?$}     , :validator => true , :click_destination => :BlogPage

  end
end
