Feature: Modular Character Creation
  As a player
  I want to create a character using rules specific to the world's genre
  So that my character fits into the setting

  Scenario: Creating a Fantasy Character
    Given I am on the World Select screen
    And I select a world with tag "Fantasy"
    When I tap "Create Character"
    Then I should see "Elf" and "Dwarf" in the Species dropdown
    And I should NOT see "Android"
