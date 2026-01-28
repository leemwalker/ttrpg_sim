import 'package:ttrpg_sim/core/database/database.dart';
import 'rpg_system.dart';

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

  @override
  int getModifier(CharacterData character, String checkName) {
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
    return ((score - 10) / 2).floor();
  }
}
