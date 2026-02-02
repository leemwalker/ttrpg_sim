import 'dart:convert';
import 'package:ttrpg_sim/core/database/database.dart';
import 'rpg_system.dart';

/// Detailed breakdown of a modifier calculation for display purposes.
class ModifierBreakdown {
  final String checkName;
  final String attributeName;
  final int attributeScore;
  final int attributeModifier;
  final int skillRank;
  final int totalModifier;

  ModifierBreakdown({
    required this.checkName,
    required this.attributeName,
    required this.attributeScore,
    required this.attributeModifier,
    required this.skillRank,
    required this.totalModifier,
  });

  /// Format the modifier with sign (e.g., "+2" or "-1")
  String formatMod(int value) => value >= 0 ? '+$value' : '$value';

  /// Short attribute abbreviation (first 3 letters, uppercase)
  String get attributeAbbrev => attributeName.substring(0, 3).toUpperCase();

  @override
  String toString() {
    final parts = <String>[];
    parts.add('$attributeAbbrev (${formatMod(attributeModifier)})');
    if (skillRank != 0) {
      parts.add('Skill (${formatMod(skillRank)})');
    }
    return parts.join(' + ');
  }
}

/// Generic Modular d20 implementation of the RPG rules system.
class CoreRpgRules extends RpgSystem {
  // Standard d20 Skill mappings (Generic)
  static const Map<String, String> _standardSkillMap = {
    'Acrobatics': 'dexterity',
    'Animal Handling': 'wisdom',
    'Arcana': 'intelligence',
    'Athletics': 'strength',
    'Deception': 'charisma',
    'History': 'intelligence',
    'Insight': 'wisdom',
    'Intimidation': 'charisma',
    'Investigation': 'intelligence',
    'Medicine': 'wisdom',
    'Nature': 'intelligence',
    'Perception': 'wisdom',
    'Performance': 'charisma',
    'Persuasion': 'charisma',
    'Religion': 'intelligence',
    'Sleight of Hand': 'dexterity',
    'Stealth': 'dexterity',
    'Survival': 'wisdom',
  };

  @override
  List<String> get availableClasses => []; // Classes removed in Modular Update

  @override
  List<String> get availableSpecies => []; // Loaded via ModularRulesController

  @override
  List<String> get availableBackgrounds =>
      []; // Loaded via ModularRulesController

  @override
  List<String> get availableFeats => []; // Loaded via ModularRulesController

  @override
  void registerCustomTraits(List<CustomTrait> traits) {
    // No-op for now as lists are managed by ModularRulesController
  }

  @override
  BackgroundInfo getBackgroundInfo(String backgroundName) {
    return BackgroundInfo(
      name: backgroundName,
      featureName: 'Unknown',
      featureDesc: 'No information available.',
      originFeat: 'None',
    );
  }

  @override
  int calculateMaxHp(String characterClass, int level) {
    // Generic d20 Formula: Base + (Level * ConMod).
    // Simplified for classless system: 10 + (Level * 6) + (ConMod * Level) ???
    // Current Character Creation uses: 10 + ConMod for level 1.
    // Let's stick to a simple generic formula:
    // Base 8 per level + Con Mod?
    // Let's use: (8 + ConMod) * Level + 2 (Base bump).
    // Or just return 10 for safety if unused.
    return 10 + (level * 5); // Fallback
  }

  @override
  Map<String, int> getMaxSpellSlots(String charClass, int level) {
    return {}; // Logic moved to Modular Magic System (if needed)
  }

  @override
  List<String> getClassFeatures(String charClass, int level) {
    return [];
  }

  @override
  List<String> getKnownSpells(String charClass, int level) {
    return [];
  }

  /// Get detailed modifier breakdown for a skill or ability check.
  /// Returns structured data with attribute and skill components.
  ModifierBreakdown getModifierBreakdown(
      CharacterData character, String checkName) {
    // Determine which attribute to use
    String attribute;
    if (_standardSkillMap.containsKey(checkName)) {
      // It's a skill - map to its governing attribute
      attribute = _standardSkillMap[checkName]!;
    } else {
      // Assume it's a raw attribute name (lowercase)
      attribute = checkName.toLowerCase();
    }

    // Get the attribute score from character data
    int score;
    switch (attribute) {
      case 'strength':
        score = character.strength;
      case 'dexterity':
        score = character.dexterity;
      case 'constitution':
        score = character.constitution;
      case 'intelligence':
        score = character.intelligence;
      case 'wisdom':
        score = character.wisdom;
      case 'charisma':
        score = character.charisma;
      default:
        score = 10; // Default fallback
    }

    // Standard d20 formula: (score - 10) / 2 (round down)
    int attrMod = ((score - 10) / 2).floor();

    // Add Skill Rank if applicable
    int skillRank = 0;
    try {
      if (character.skills.isNotEmpty) {
        final Map<String, dynamic> skillsMap = jsonDecode(character.skills);
        if (skillsMap.containsKey(checkName)) {
          skillRank = skillsMap[checkName] as int? ?? 0;
        }
      }
    } catch (e) {
      print('Error parsing skills for modifier: $e');
    }

    // Capitalize attribute name for display
    final displayAttr = attribute[0].toUpperCase() + attribute.substring(1);

    return ModifierBreakdown(
      checkName: checkName,
      attributeName: displayAttr,
      attributeScore: score,
      attributeModifier: attrMod,
      skillRank: skillRank,
      totalModifier: attrMod + skillRank,
    );
  }

  @override
  int getModifier(CharacterData character, String checkName) {
    return getModifierBreakdown(character, checkName).totalModifier;
  }
}
