Feature: Modular Character Creation
  As a player
  I want to create a character using rules specific to the world's genre
  So that my character fits into the setting

  Scenario: Creating a Fantasy Character
    Given I am on the World Select screen
    And I select a world with tag "Fantasy"
    When I tap "Create Character"
    Then I should see "Elf" species option
    And I should see "Dwarf" species option
    And I should NOT see "Android" species option

  Scenario: Functioning Origin Filter
    Given I have selected "Star Wars" (Sci-Fi)
    When I reach the Origin selection step
    Then I should see "Smuggler" origin option
    And I should NOT see "Wizard" origin option
