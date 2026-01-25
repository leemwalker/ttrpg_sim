import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
import 'package:ttrpg_sim/core/database/database.dart';

void main() {
  group('Dnd5eRules Unit Tests', () {
    late Dnd5eRules rules;

    setUp(() {
      rules = Dnd5eRules();
    });

    // Task 1.1: calculateMaxHp
    test('calculateMaxHp returns correct values for Fighter', () {
      // Fighter Hit Die is d10.
      // Level 1: Max Die (10)
      expect(rules.calculateMaxHp('Fighter', 1), 10);

      // Level 2: 10 + (10 / 2 + 1) = 10 + 6 = 16
      expect(rules.calculateMaxHp('Fighter', 2), 16);

      // Level 3: 16 + 6 = 22
      expect(rules.calculateMaxHp('Fighter', 3), 22);
    });

    test('calculateMaxHp returns correct values for Wizard', () {
      // Wizard Hit Die is d6.
      // Level 1: Max Die (6)
      expect(rules.calculateMaxHp('Wizard', 1), 6);

      // Level 2: 6 + (6 / 2 + 1) = 6 + 4 = 10
      expect(rules.calculateMaxHp('Wizard', 2), 10);
    });

    // Task 1.2: getModifier
    test('getModifier calculates correct ability modifiers', () {
      // Wrapper to create dummy character data with specific stats
      CharacterData createChar(int score, String attr) {
        return CharacterData(
          id: 1,
          worldId: 1,
          location: 'Unknown',
          name: 'Test',
          heroClass: 'Fighter',
          species: 'Human',
          background: 'Noble',
          level: 1,
          currentHp: 10,
          maxHp: 10,
          strength: attr == 'strength' ? score : 10,
          dexterity: attr == 'dexterity' ? score : 10,
          constitution: attr == 'constitution' ? score : 10,
          intelligence: attr == 'intelligence' ? score : 10,
          wisdom: attr == 'wisdom' ? score : 10,
          charisma: attr == 'charisma' ? score : 10,
          gold: 0,
        );
      }

      // 8 -> -1
      final c = createChar(8, 'strength');
      expect(rules.getModifier(c, 'strength'), -1);
      // 9 -> -1
      expect(rules.getModifier(createChar(9, 'dexterity'), 'dexterity'), -1);
      // 10 -> 0
      expect(
          rules.getModifier(createChar(10, 'constitution'), 'constitution'), 0);
      // 11 -> 0
      expect(
          rules.getModifier(createChar(11, 'intelligence'), 'intelligence'), 0);
      // 12 -> +1
      expect(rules.getModifier(createChar(12, 'wisdom'), 'wisdom'), 1);
      // 15 -> +2
      expect(rules.getModifier(createChar(15, 'charisma'), 'charisma'), 2);
      // 20 -> +5
      expect(rules.getModifier(createChar(20, 'strength'), 'strength'), 5);
    });

    // Task 1.3: getBackgroundInfo
    test('getBackgroundInfo returns correct features', () {
      final noble = rules.getBackgroundInfo('Noble');
      expect(noble.name, 'Noble');
      expect(noble.featureName, 'Position of Privilege');
      expect(noble.originFeat, 'Skilled');

      final acolyte = rules.getBackgroundInfo('Acolyte');
      expect(acolyte.name, 'Acolyte');
      expect(acolyte.featureName, 'Shelter of the Faithful');
    });

    // Additional: getClassFeatures (Integration check)
    test('getClassFeatures returns features for level', () {
      final fighterLvl1 = rules.getClassFeatures('Fighter', 1);
      expect(fighterLvl1, contains('Second Wind'));
      expect(fighterLvl1, isNot(contains('Action Surge')));

      final fighterLvl2 = rules.getClassFeatures('Fighter', 2);
      expect(fighterLvl2, contains('Second Wind'));
      expect(fighterLvl2, contains('Action Surge'));
    });
  });
}
