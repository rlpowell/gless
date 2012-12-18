# encoding: utf-8

module TestGithub
  class FeaturesPage < TestGithub::BasePage

    url %r{^:base_url/features/projects$}

    expected_title 'Features / Project Management · GitHub'

    # Stub page, but BasePage stuff still works

  end
end
