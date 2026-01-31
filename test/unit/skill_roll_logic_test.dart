import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/core_rpg_rules.dart';

void main() {
  group('CoreRpgRules Skill Roll Logic', () {
    late CoreRpgRules rules;

    setUp(() {
      rules = CoreRpgRules();
    });

    test('getModifier includes both Attribute Mod and Skill Rank', () {
      final char = CharacterData(
        id: 1,
        name: 'Test Hero',
        species: 'Human',
        origin: 'Warrior',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 0,
        location: 'Unknown',
        // Attributes
        strength: 14, // +2
        dexterity: 10, // +0
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 16, // +3
        // Skills: JSON Map <String, int>
        skills: jsonEncode({
          'Athletics': 1, // governed by STR
          'Stealth': 2, // governed by DEX
          'Persuasion': 1, // governed by CHA
        }),
        attributes: '{}',
        traits: '[]',
        feats: '[]',
        inventory: '[]',
        spells: '[]',
        currentMana: 0,
        maxMana: 0,
        worldId: 1,
      );

      // 1. Athletics (Str)
      // Mod: Str 14 (+2) + Rank 1 = +3
      expect(rules.getModifier(char, 'Athletics'), equals(3),
          reason: 'Athletics shoud be Str(+2) + Rank(1) = 3');

      // 2. Stealth (Dex)
      // Mod: Dex 10 (+0) + Rank 2 = +2
      expect(rules.getModifier(char, 'Stealth'), equals(2),
          reason: 'Stealth shoud be Dex(+0) + Rank(2) = 2');

      // 3. Persuasion (Cha)
      // Mod: Cha 16 (+3) + Rank 1 = +4
      expect(rules.getModifier(char, 'Persuasion'), equals(4),
          reason: 'Persuasion shoud be Cha(+3) + Rank(1) = 4');

      // 4. Raw Attribute Check (Strength)
      // Mod: Str 14 (+2) -> +2
      expect(rules.getModifier(char, 'Strength'), equals(2),
          reason: 'Pure Strength check should just be modifier (+2)');

      // 5. Unskilled Skill (Perception - Wis)
      // Mod: Wis 10 (+0) + Rank 0 = 0
      expect(rules.getModifier(char, 'Perception'), equals(0),
          reason: 'Unskilled Perception should be Wis(+0) + Rank(0) = 0');
    });
  });
}
