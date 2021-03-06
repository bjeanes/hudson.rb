@authentication
Feature: Authentication
  In order to allow me to protect my source code and build status from outsiders
  As a developer
  I want to control a Hudson instance that requires authentication

  Background:
    Given I have a Hudson server running
    And the Hudson server has no current jobs
    And managing the Hudson server requires authenticating

  Scenario: Not authenticated
    When I run local executable "hudson" with arguments "list --host localhost --port 3010"
    Then I should see "Authentication required. Please use --username and --password options"

