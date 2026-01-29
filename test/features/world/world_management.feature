Feature: World Management
  As a Player
  I want to manage my Worlds
  So that I can keep my game list organized

  Scenario: Delete a World
    Given a World named "Test World" exists
    And a Character exists in "Test World"
    When I delete "Test World"
    Then "Test World" should no longer exist
    And the Character should strictly be deleted
