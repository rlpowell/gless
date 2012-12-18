module TestGithub
  class TestGithub::BasePage < Gless::BasePage

    element :home     , :link , :href => "https://github.com/"         , :validator => true , :click_destination => :LoginPage
    element :explore  , :link , :href => "https://github.com/explore"  , :validator => true , :click_destination => :ExplorePage
    element :search   , :link , :href => "https://github.com/search"   , :validator => true , :click_destination => :SearchPage
    element :features , :link , :href => "https://github.com/features" , :validator => true , :click_destination => :FeaturesPage
    element :blog     , :link , :href => "https://github.com/blog"     , :validator => true , :click_destination => :BlogPage

  end
end
