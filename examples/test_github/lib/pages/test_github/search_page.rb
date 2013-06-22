# encoding: utf-8

module TestGithub
  class SearchPage < TestGithub::BasePage

    element :search_form   , :form       , :id    => 'search_form'       , :validator => true
    element :search_input  , :text_field , :class => 'search-page-input' , :validator => true , :parent => :search_form
    element :search_button , :button     , :text  => 'Search'            , :validator => true , :parent => :search_form

    element :repository_list  , :ul   , :class => /\brepolist\b/
    element :repository_link  , :link , :click_destination => :RepoPage , :parent => :repository_list , :proc => -> repos, name do
      repos.a(:text => name)
    end
    element :repository_elems , :lis  , :class => 'public source'       , :parent => :repository_list

    # Test validator blocks.
    add_validator do |browser, session|
      browser.url =~ /search/
    end

    url %r{^:base_url/search}
    set_entry_url ':base_url/search'

    expected_title %r{^(Code Search · GitHub|Search · \S+ · GitHub)$}

    def search_for stuff
      self.search_input.set stuff
      self.search_button.click
    end

    def goto_repository name
      @session.log.debug "SearchPage: goto_repository: name: #{name}"
      repository_link(name).click
    end

    def find_repository name
      @session.log.debug "SearchPage: find_repository: name: #{name}"
      if name.is_a?(Regexp)
        key = repositories.keys.find { |key| key =~ name }
      elsif name.is_a?(String)
        key = name
      end

      @session.log.debug "SearchPage: find_repository: key: #{key}"

      repositories[key]
    end

    def repositories
      repos = repository_elems

      @session.log.debug "SearchPage: repositories: repos: #{repos.inspect}"

      repositories = Hash.new
      i = 0
      repos.each do |repo|
        link = repo.h3.a
        data = Hash.new
        data[:index] = i
        data[:link] = link
        data[:url] = link.href
        data[:name] = link.text
        repositories[link.text] = data
        i += 1
      end

      @session.log.debug "SearchPage: repositories: final: #{repositories.inspect}"

      repositories
    end

  end
end
