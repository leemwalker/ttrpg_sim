Feature: Grimoire Casting
  As a magic user
  I want to cast spells from my detailed Grimoire
  So that I can affect the game world and track my mana

  Scenario: Casting a Spell Deducts Mana
    Given I have a character with "Fireball" spell
    And my current mana is 10
    When I navigate to "Grimoire" tab
    And I tap "Cast" on "Fireball"
    Then I see a chat message "Player casts Fireball"
    And my mana should be 9
