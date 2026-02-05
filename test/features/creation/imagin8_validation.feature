Feature: Imagin8 Card Validation
  As a Player
  I want to ensure my hand is valid according to Imagin8 rules
  So that I play with a fair character

  Background:
    Given the Imagin8 Character Creation screen is open

  Scenario: Character with 9 cards containing 2 abilities and only 1 drawback is invalid
    # 6 Normal + 2 Abilities = 8 Normal (Max allowed)
    # 1 Drawback
    # Total = 9 Cards
    # Invalid because: 2 Abilities > 1 Drawback
    When I select 6 "Trait" cards
    And I select 2 "Ability" cards
    And I select 1 "Drawback" cards
    Then I should see a validation error "Unbalanced! Need 1 more Drawback(s)"
    And the Create Character button should be disabled

  Scenario: Character with more than 8 normal cards is invalid
    When I select 9 "Trait" cards
    Then I should see a validation error "Max 8 normal cards allowed"
    And the Create Character button should be disabled

  Scenario: Character with 8 normal cards and matched drawbacks is valid
    # 6 Normal + 2 Abilities = 8 Normal
    # 2 Drawbacks (matches 2 abilities)
    # Total = 10 Cards
    When I select 6 "Trait" cards
    And I select 2 "Ability" cards
    And I select 2 "Drawback" cards
    Then I should not see any validation errors
    And the Create Character button should be enabled
