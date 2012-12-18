Feature: Test Github Searching

  Scenario: Find The Gless Repo
    Given I start the application
    When I go to the Gless repo via the search page
    Then I am on the Gless repo page

  Scenario: Poke Around
    Given I start the application
    When I poke lots of buttons
    And I fall through to the page object
    Then I am on the Features page
