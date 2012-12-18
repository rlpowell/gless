# encoding: utf-8

module TestGithub
  class LoginPage < TestGithub::BasePage

    url %r{^:base_url/?$}

    set_entry_url ':base_url'

    expected_title 'GitHub · Build software better, together.'

    # Stub page, but BasePage stuff still works

  end
end
