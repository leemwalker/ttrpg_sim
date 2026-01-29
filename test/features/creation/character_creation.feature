Feature: Character Creation
  As a Player
  I want to create a character with options suitable for my World's Genre
  So that I can play the game with a fitting avatar

  Scenario: Character Creation Options Populate Correctly
    Given the Modular Rules are loaded
    And a World exists with genre "Fantasy"
    When I access the Character Creation screen for this World
    Then I should see "Human" and "Elf" as Species options
    And I should see "Warrior" and "Mage" as Origin options
    And I should see "Strong" and "Wise" as Trait options

  Scenario: Character Creation UI Overflow
    Given the Character Creation screen is open
    When I view the Stepper navigation
    Then the Stepper should not overflow the screen width

  Scenario: Attributes and Skills are populated
    Given I have selected a Species and Origin
    When I reach the Attributes step
    Then I should see "Strength", "Agility" and "Mind" as Attributes
    And I should see "Melee", "Arcana" and "Stealth" as Skills
