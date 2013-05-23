# encoding: utf-8

module TestGithub
  class BlogPage < TestGithub::BasePage

    url %r{^:base_url/blog$}

    expected_title 'The GitHub Blog · GitHub'

    # Stub page, but BasePage stuff still works

  end
end
