# encoding: utf-8

module TestGithub
  class RepoPage < TestGithub::BasePage

    # Not much of a restriction
    url %r{^:base_url}

    expected_title %r{^\S+ · GitHub$}

    # Stub page, but BasePage stuff still works

  end
end
