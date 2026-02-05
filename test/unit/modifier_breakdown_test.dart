import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/core_rpg_rules.dart';

void main() {
  group('ModifierBreakdown', () {
    late CoreRpgRules rules;

    setUp(() {
      rules = CoreRpgRules();
    });

    CharacterData createTestCharacter({
      int strength = 10,
      int dexterity = 10,
      int constitution = 10,
      int intelligence = 10,
      int wisdom = 10,
      int charisma = 10,
      String skills = '{}',
    }) {
      return CharacterData(
        id: 1,
        worldId: 1,
        name: 'Test Hero',
        species: 'Human',
        origin: 'Adventurer',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 100,
        strength: strength,
        dexterity: dexterity,
        constitution: constitution,
        intelligence: intelligence,
        wisdom: wisdom,
        charisma: charisma,
        attributes: '{}',
        skills: skills,
        traits: '[]',
        feats: '[]',
        inventory: '[]',
        spells: '[]',
        currentMana: 0,
        maxMana: 0,
        location: 'Town',
        armorClass: 10,
        xp: 0,
        equipment: '{}',
        hand: '[]',
        discardPile: '[]',
      );
    }

    test('calculates attribute modifier correctly', () {
      // Dexterity 14 = +2 modifier
      final char = createTestCharacter(dexterity: 14);
      final breakdown = rules.getModifierBreakdown(char, 'dexterity');

      expect(breakdown.attributeName, equals('Dexterity'));
      expect(breakdown.attributeScore, equals(14));
      expect(breakdown.attributeModifier, equals(2));
      expect(breakdown.skillRank, equals(0));
      expect(breakdown.totalModifier, equals(2));
    });

    test('handles low attribute scores correctly', () {
      // Strength 8 = -1 modifier
      final char = createTestCharacter(strength: 8);
      final breakdown = rules.getModifierBreakdown(char, 'strength');

      expect(breakdown.attributeModifier, equals(-1));
      expect(breakdown.totalModifier, equals(-1));
    });

    test('maps skills to correct attributes', () {
      final char = createTestCharacter(dexterity: 16);

      // Stealth uses Dexterity
      final breakdown = rules.getModifierBreakdown(char, 'Stealth');

      expect(breakdown.attributeName, equals('Dexterity'));
      expect(breakdown.attributeModifier, equals(3)); // (16-10)/2 = 3
    });

    test('includes skill rank in breakdown', () {
      final char = createTestCharacter(
        dexterity: 14,
        skills: '{"Stealth": 3}',
      );
      final breakdown = rules.getModifierBreakdown(char, 'Stealth');

      expect(breakdown.attributeModifier, equals(2)); // (14-10)/2 = 2
      expect(breakdown.skillRank, equals(3));
      expect(breakdown.totalModifier, equals(5)); // 2 + 3
    });

    test('formatMod adds plus sign for positive values', () {
      final char = createTestCharacter(charisma: 16);
      final breakdown = rules.getModifierBreakdown(char, 'charisma');

      expect(breakdown.formatMod(3), equals('+3'));
      expect(breakdown.formatMod(0), equals('+0'));
      expect(breakdown.formatMod(-2), equals('-2'));
    });

    test('attributeAbbrev returns 3-letter abbreviation', () {
      final char = createTestCharacter(intelligence: 14);
      final breakdown = rules.getModifierBreakdown(char, 'intelligence');

      expect(breakdown.attributeAbbrev, equals('INT'));
    });

    test('toString formats breakdown correctly without skill', () {
      final char = createTestCharacter(wisdom: 16);
      final breakdown = rules.getModifierBreakdown(char, 'wisdom');

      expect(breakdown.toString(), equals('WIS (+3)'));
    });

    test('toString formats breakdown correctly with skill', () {
      final char = createTestCharacter(
        wisdom: 14,
        skills: '{"Perception": 2}',
      );
      final breakdown = rules.getModifierBreakdown(char, 'Perception');

      expect(breakdown.toString(), equals('WIS (+2) + Skill (+2)'));
    });

    test('getModifier returns same total as breakdown', () {
      final char = createTestCharacter(
        dexterity: 16,
        skills: '{"Acrobatics": 4}',
      );

      final modifier = rules.getModifier(char, 'Acrobatics');
      final breakdown = rules.getModifierBreakdown(char, 'Acrobatics');

      expect(modifier, equals(breakdown.totalModifier));
      expect(modifier, equals(7)); // DEX +3 + Skill +4
    });

    test('handles missing skills gracefully', () {
      final char = createTestCharacter(
        charisma: 12,
        skills: '{}',
      );
      final breakdown = rules.getModifierBreakdown(char, 'Persuasion');

      expect(breakdown.skillRank, equals(0));
      expect(breakdown.totalModifier, equals(1)); // (12-10)/2 = 1
    });

    test('handles malformed skills JSON gracefully', () {
      final char = createTestCharacter(
        dexterity: 14,
        skills: 'invalid json',
      );
      final breakdown = rules.getModifierBreakdown(char, 'Stealth');

      // Should not throw, just use 0 for skill rank
      expect(breakdown.skillRank, equals(0));
      expect(breakdown.totalModifier, equals(2));
    });
  });
}
