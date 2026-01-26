import 'package:ttrpg_sim/core/database/database.dart';
import 'rpg_system.dart';

/// D&D 5e SRD implementation of the RPG rules system.
class Dnd5eRules extends RpgSystem {
  // Hit die per class (used for HP calculation)
  static const Map<String, int> _hitDice = {
    'Barbarian': 12,
    'Bard': 8,
    'Cleric': 8,
    'Druid': 8,
    'Fighter': 10,
    'Monk': 8,
    'Paladin': 10,
    'Ranger': 10,
    'Rogue': 8,
    'Sorcerer': 6,
    'Warlock': 8,
    'Wizard': 6,
  };

  // D&D 5e SRD: Map of skills to their governing attributes
  static const Map<String, String> _skillAttributes = {
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

  // Mutable lists to allow homebrew content
  late final List<String> _classes;
  late final List<String> _species;

  Dnd5eRules() {
    _classes = _hitDice.keys.toList()..sort();
    _species = [
      'Human',
      'Elf',
      'Dwarf',
      'Halfling',
      'Dragonborn',
      'Gnome',
      'Half-Elf',
      'Half-Orc',
      'Tiefling',
    ];
  }

  @override
  List<String> get availableClasses => _classes;

  @override
  List<String> get availableSpecies => _species;

  @override
  void registerCustomTraits(List<CustomTrait> traits) {
    for (final trait in traits) {
      if (trait.type == 'Class' && !_classes.contains(trait.name)) {
        _classes.add(trait.name);
      } else if (trait.type == 'Species' && !_species.contains(trait.name)) {
        _species.add(trait.name);
      }
    }
  }

  @override
  List<String> get availableBackgrounds => [
        'Acolyte',
        'Criminal',
        'Folk Hero',
        'Noble',
        'Sage',
        'Soldier',
        'Merchant',
        'Outlander',
      ];

  static const Map<String, BackgroundInfo> _backgrounds = {
    'Acolyte': BackgroundInfo(
      name: 'Acolyte',
      featureName: 'Shelter of the Faithful',
      featureDesc:
          'You command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith.',
      originFeat: 'Magic Initiate (Cleric)',
    ),
    'Criminal': BackgroundInfo(
      name: 'Criminal',
      featureName: 'Criminal Contact',
      featureDesc:
          'You have a reliable and trustworthy contact who acts as your liaison to a network of other criminals. You know how to get messages to and from your contact, even over great distances.',
      originFeat: 'Alert',
    ),
    'Folk Hero': BackgroundInfo(
      name: 'Folk Hero',
      featureName: 'Rustic Hospitality',
      featureDesc:
          'Since you come from the ranks of the common folk, you fit in among them with ease. You can find a place to hide, rest, or recuperate among other commoners, unless you have shown yourself to be a danger to them.',
      originFeat: 'Tough',
    ),
    'Noble': BackgroundInfo(
      name: 'Noble',
      featureName: 'Position of Privilege',
      featureDesc:
          'Thanks to your noble birth, people are inclined to think the best of you. You are welcome in high society, and people assume you have the right to be wherever you are. The common folk make every effort to accommodate you and avoid your displeasure.',
      originFeat: 'Skilled',
    ),
    'Sage': BackgroundInfo(
      name: 'Sage',
      featureName: 'Researcher',
      featureDesc:
          'When you attempt to learn or recall a piece of lore, if you do not know that information, you often know where and from whom you can obtain it.',
      originFeat: 'Magic Initiate (Wizard)',
    ),
    'Soldier': BackgroundInfo(
      name: 'Soldier',
      featureName: 'Military Rank',
      featureDesc:
          'You have a military rank from your career as a soldier. Soldiers loyal to your former military organization still recognize your authority and influence, and they defer to you if they are of a lower rank.',
      originFeat: 'Savage Attacker',
    ),
    'Merchant': BackgroundInfo(
      name: 'Merchant',
      featureName: 'Guild Membership',
      featureDesc:
          'As an established and respected member of a guild, you can rely on certain benefits that membership provides. Your fellow guild members will provide you with lodging and food if necessary, and pay for your funeral if needed.',
      originFeat: 'Lucky',
    ),
    'Outlander': BackgroundInfo(
      name: 'Outlander',
      featureName: 'Wanderer',
      featureDesc:
          'You have an excellent memory for maps and geography, and you can always recall the general layout of terrain, settlements, and other features around you. In addition, you can find food and fresh water for yourself and up to five other people each day.',
      originFeat: 'Musician',
    ),
  };

  @override
  BackgroundInfo getBackgroundInfo(String backgroundName) {
    return _backgrounds[backgroundName] ??
        BackgroundInfo(
          name: backgroundName,
          featureName: 'Unknown',
          featureDesc: 'No information available.',
          originFeat: 'None',
        );
  }

  @override
  int calculateMaxHp(String characterClass, int level,
      [int conScore = 10, List<String> feats = const []]) {
    final hitDie = _hitDice[characterClass] ?? 8;
    final conMod = ((conScore - 10) / 2).floor();
    final toughBonus = feats.contains('Tough') ? 2 * level : 0;

    // SRD Formula: Max Hit Die at Level 1 + (Hit Die / 2 + 1) * (Level - 1)
    // + (CON Modifier * Level) + Feat Bonuses
    if (level == 1) {
      return hitDie + conMod + toughBonus;
    }

    final avgPerLevel = (hitDie ~/ 2) + 1;
    final baseHp = hitDie + (avgPerLevel * (level - 1));
    final conHp = conMod * level;

    return baseHp + conHp + toughBonus;
  }

  // Class features by class and level (cumulative up to level)
  static const Map<String, Map<int, List<String>>> _classFeatures = {
    'Fighter': {
      1: ['Second Wind'],
      2: ['Second Wind', 'Action Surge'],
      3: ['Second Wind', 'Action Surge', 'Martial Archetype'],
    },
    'Rogue': {
      1: ['Sneak Attack', 'Thieves\' Cant'],
      2: ['Sneak Attack', 'Thieves\' Cant', 'Cunning Action'],
      3: [
        'Sneak Attack',
        'Thieves\' Cant',
        'Cunning Action',
        'Roguish Archetype'
      ],
    },
    'Wizard': {
      1: ['Arcane Recovery', 'Spellcasting'],
      2: ['Arcane Recovery', 'Spellcasting', 'Arcane Tradition'],
      3: ['Arcane Recovery', 'Spellcasting', 'Arcane Tradition'],
    },
    'Cleric': {
      1: ['Spellcasting', 'Divine Domain'],
      2: ['Spellcasting', 'Divine Domain', 'Channel Divinity'],
      3: ['Spellcasting', 'Divine Domain', 'Channel Divinity'],
    },
  };

  // Spell slots for full casters by level
  static const Map<int, Map<String, int>> _casterSpellSlots = {
    1: {'1st': 2},
    2: {'1st': 3},
    3: {'1st': 4, '2nd': 2},
  };

  // Known spells by class (MVP: static list of iconic spells)
  static const Map<String, List<String>> _knownSpells = {
    'Wizard': ['Magic Missile', 'Shield', 'Mage Armor', 'Fire Bolt', 'Light'],
    'Cleric': ['Cure Wounds', 'Bless', 'Guiding Bolt', 'Sacred Flame'],
    'Sorcerer': ['Magic Missile', 'Shield', 'Fire Bolt', 'Ray of Frost'],
    'Bard': ['Healing Word', 'Thunderwave', 'Vicious Mockery'],
    'Druid': ['Cure Wounds', 'Entangle', 'Produce Flame'],
    'Warlock': ['Eldritch Blast', 'Hex', 'Armor of Agathys'],
    'Paladin': ['Cure Wounds', 'Divine Smite', 'Shield of Faith'],
    'Ranger': ['Cure Wounds', 'Hunter\'s Mark', 'Ensnaring Strike'],
  };

  // Classes that have spellcasting
  static const Set<String> _fullCasters = {
    'Wizard',
    'Cleric',
    'Sorcerer',
    'Bard',
    'Druid',
  };

  static const Set<String> _halfCasters = {
    'Paladin',
    'Ranger',
  };

  @override
  Map<String, int> getMaxSpellSlots(String charClass, int level) {
    // Full casters get slots at level 1
    if (_fullCasters.contains(charClass)) {
      return _casterSpellSlots[level] ?? {};
    }
    // Half casters get slots at level 2
    if (_halfCasters.contains(charClass) && level >= 2) {
      // Half caster slot progression (simplified)
      final effectiveLevel = (level / 2).ceil();
      return _casterSpellSlots[effectiveLevel] ?? {};
    }
    // Warlock uses Pact Magic (simplified as regular slots for MVP)
    if (charClass == 'Warlock') {
      return _casterSpellSlots[level] ?? {};
    }
    // Non-casters (Fighter, Rogue, Barbarian, Monk)
    return {};
  }

  @override
  List<String> getClassFeatures(String charClass, int level) {
    final classMap = _classFeatures[charClass];
    if (classMap == null) return [];

    // Find the highest level entry at or below the requested level
    final availableLevels = classMap.keys.where((l) => l <= level).toList();
    if (availableLevels.isEmpty) return [];

    final highestLevel = availableLevels.reduce((a, b) => a > b ? a : b);
    return classMap[highestLevel] ?? [];
  }

  @override
  List<String> getKnownSpells(String charClass, int level) {
    // Only return spells if the class can cast
    if (!_fullCasters.contains(charClass) &&
        !_halfCasters.contains(charClass) &&
        charClass != 'Warlock') {
      return [];
    }
    // Half casters don't get spells until level 2
    if (_halfCasters.contains(charClass) && level < 2) {
      return [];
    }
    return _knownSpells[charClass] ?? [];
  }

  @override
  int getModifier(CharacterData character, String checkName) {
    // Determine which attribute to use
    String attribute;
    if (_skillAttributes.containsKey(checkName)) {
      // It's a skill - map to its governing attribute
      attribute = _skillAttributes[checkName]!;
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
        score = 10; // Default fallback for unknown attributes
    }

    // D&D 5e formula: (score - 10) / 2 (round down)
    return ((score - 10) / 2).floor();
  }
}
