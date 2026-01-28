Feature: Grimoire Casting
  As a spellcaster
  I want to cast spells from my grimoire
  So that I can use magic in the game

  Scenario: Casting a Cost 0 Spell
    Given I have a character with 5 Mana
    And I have a spell "Firebolt" (Cost 0)
    When I tap "Firebolt"
    Then the Mana should remain 5
    And a system message "Casts Firebolt" should appear in chat

  Scenario: Casting a Leveled Spell
    Given I have a character with 10 Mana
    And I have a spell "Fireball" (Cost 3)
    When I tap "Fireball"
    Then the Mana should become 7
    And a system message "Casts Fireball" should appear in chat
