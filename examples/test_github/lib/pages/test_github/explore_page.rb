# encoding: utf-8

module TestGithub
  class ExplorePage < TestGithub::BasePage

    url %r{^:base_url/explore$}

    expected_title 'Explore · GitHub'

    # Stub page, but BasePage stuff still works

  end
end
