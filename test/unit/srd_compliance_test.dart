import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
import 'package:ttrpg_sim/core/database/database.dart';

/// Tests to verify strict SRD 5.2.1 compliance for Dnd5eRules.
/// Per project requirements, defaults must ONLY include SRD 5.2.1 content.
/// Non-SRD content must be added via CustomTraits.
void main() {
  group('SRD 5.2.1 Compliance Tests', () {
    late Dnd5eRules rules;

    setUp(() {
      rules = Dnd5eRules();
    });

    // =========================================================================
    // Test 1: Species match SRD 5.2.1 exactly
    // =========================================================================
    test('availableSpecies contains exactly 9 SRD species', () {
      const expectedSpecies = [
        'Dragonborn',
        'Dwarf',
        'Elf',
        'Gnome',
        'Goliath',
        'Halfling',
        'Human',
        'Orc',
        'Tiefling',
      ];

      expect(rules.availableSpecies.length, equals(9));
      expect(rules.availableSpecies, containsAll(expectedSpecies));
    });

    // =========================================================================
    // Test 2: Backgrounds match SRD 5.2.1 exactly
    // =========================================================================
    test('availableBackgrounds contains exactly 4 SRD backgrounds', () {
      const expectedBackgrounds = [
        'Acolyte',
        'Criminal',
        'Sage',
        'Soldier',
      ];

      expect(rules.availableBackgrounds.length, equals(4));
      expect(rules.availableBackgrounds, equals(expectedBackgrounds));
    });

    // =========================================================================
    // Test 3: Feats contain SRD feats
    // =========================================================================
    test('availableFeats contains SRD feats', () {
      expect(rules.availableFeats, contains('Grappler'));
      expect(rules.availableFeats, contains('Alert'));
      expect(rules.availableFeats, contains('Magic Initiate'));
      expect(rules.availableFeats, contains('Savage Attacker'));
      expect(rules.availableFeats, contains('Skilled'));
      expect(rules.availableFeats, contains('Ability Score Improvement'));
    });

    // =========================================================================
    // Test 4: Non-SRD content is NOT present by default
    // =========================================================================
    test('non-SRD content is NOT present by default', () {
      // Half-Elf removed in SRD 5.2.1 (replaced by Orc)
      expect(rules.availableSpecies, isNot(contains('Half-Elf')));
      // Half-Orc is now just "Orc" in SRD 5.2.1
      expect(rules.availableSpecies, isNot(contains('Half-Orc')));

      // Noble background not in SRD 5.2.1
      expect(rules.availableBackgrounds, isNot(contains('Noble')));
      // Folk Hero background not in SRD 5.2.1
      expect(rules.availableBackgrounds, isNot(contains('Folk Hero')));
      // Merchant background not in SRD 5.2.1
      expect(rules.availableBackgrounds, isNot(contains('Merchant')));
      // Outlander background not in SRD 5.2.1
      expect(rules.availableBackgrounds, isNot(contains('Outlander')));

      // Artificer class not in SRD
      expect(rules.availableClasses, isNot(contains('Artificer')));
    });

    // =========================================================================
    // Test 5: CustomTraits extensibility for Feats
    // =========================================================================
    test('registerCustomTraits adds custom feat to availableFeats', () {
      const customFeat = CustomTrait(
        id: 1,
        name: 'MyHomebrewFeat',
        type: 'Feat',
        description: 'A custom homebrew feat for testing.',
      );

      rules.registerCustomTraits([customFeat]);
      expect(rules.availableFeats, contains('MyHomebrewFeat'));
    });

    test('registerCustomTraits does not duplicate existing feats', () {
      const duplicateFeat = CustomTrait(
        id: 2,
        name: 'Alert', // Already a default feat
        type: 'Feat',
        description: 'Attempting to add duplicate.',
      );

      final initialLength = rules.availableFeats.length;
      rules.registerCustomTraits([duplicateFeat]);
      expect(rules.availableFeats.length, equals(initialLength));
    });

    // =========================================================================
    // Test 6: Classes match SRD 5.2.1
    // =========================================================================
    test('availableClasses contains exactly 12 SRD classes', () {
      const expectedClasses = [
        'Barbarian',
        'Bard',
        'Cleric',
        'Druid',
        'Fighter',
        'Monk',
        'Paladin',
        'Ranger',
        'Rogue',
        'Sorcerer',
        'Warlock',
        'Wizard',
      ];

      expect(rules.availableClasses.length, equals(12));
      expect(rules.availableClasses, containsAll(expectedClasses));
    });
  });
}
