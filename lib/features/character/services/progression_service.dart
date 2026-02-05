import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

/// XP thresholds for each level (Pathfinder 2e simplified)
class XpThresholds {
  /// Get XP required to reach a level
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 300;
    if (level == 3) return 600;
    if (level == 4) return 1000;
    // Level 5+: 1000 + 500 per level above 4
    return 1000 + (level - 4) * 500;
  }

  /// Get XP needed from current level to next level
  static int xpToNextLevel(int currentLevel) {
    return xpForLevel(currentLevel + 1) - xpForLevel(currentLevel);
  }
}

/// Choices made during level up
class LevelUpChoices {
  /// Attribute to boost (every 4 levels, first choice)
  final String? attributeBoost1;

  /// Attribute to boost (every 4 levels, second choice)
  final String? attributeBoost2;

  /// New feat selected
  final String? selectedFeat;

  const LevelUpChoices({
    this.attributeBoost1,
    this.attributeBoost2,
    this.selectedFeat,
  });
}

/// Service for managing character progression (XP, leveling, HP)
class ProgressionService {
  final GameDao _dao;

  ProgressionService(this._dao);

  /// Calculate HP bonus per level from traits
  /// Parses effect field for patterns like "+1 Max HP per Level" or "-1 Max HP per Level"
  int calculateHpBonusFromTraits(
      List<String> characterTraits, List<TraitDef> allTraits) {
    int bonus = 0;
    for (final traitName in characterTraits) {
      final trait = allTraits.firstWhere(
        (t) => t.name.toLowerCase() == traitName.toLowerCase(),
        orElse: () => TraitDef(
            name: '',
            type: '',
            cost: 0,
            genre: '',
            description: '',
            effect: ''),
      );
      bonus += _parseHpPerLevelEffect(trait.effect);
    }
    return bonus;
  }

  /// Calculate HP bonus per level from feats
  int calculateHpBonusFromFeats(
      List<String> characterFeats, List<FeatDef> allFeats) {
    int bonus = 0;
    for (final featName in characterFeats) {
      final feat = allFeats.firstWhere(
        (f) => f.name.toLowerCase() == featName.toLowerCase(),
        orElse: () => FeatDef(
            name: '',
            genre: '',
            type: '',
            prerequisite: '',
            description: '',
            effect: ''),
      );
      bonus += _parseHpPerLevelEffect(feat.effect);
    }
    return bonus;
  }

  /// Parse effect string for HP per level modifier
  /// Matches patterns: "+1 Max HP per Level", "-1 Max HP per Level", "+1 HP per level"
  int _parseHpPerLevelEffect(String effect) {
    final regex = RegExp(r'([+-]?\d+)\s*(?:Max\s*)?HP\s*per\s*Level',
        caseSensitive: false);
    final match = regex.firstMatch(effect);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Calculate total HP at a given level
  /// Formula: level * (8 + ConMod + TraitBonus + FeatBonus)
  int calculateMaxHp({
    required int level,
    required int constitution,
    required List<String> traits,
    required List<String> feats,
    required List<TraitDef> allTraits,
    required List<FeatDef> allFeats,
  }) {
    final conMod = ((constitution - 10) / 2).floor();
    final traitBonus = calculateHpBonusFromTraits(traits, allTraits);
    final featBonus = calculateHpBonusFromFeats(feats, allFeats);

    final hpPerLevel = 8 + conMod + traitBonus + featBonus;
    // Minimum 1 HP per level
    return level * (hpPerLevel < 1 ? 1 : hpPerLevel);
  }

  /// Calculate HP per level for display purposes
  int calculateHpPerLevel({
    required int constitution,
    required List<String> traits,
    required List<String> feats,
    required List<TraitDef> allTraits,
    required List<FeatDef> allFeats,
  }) {
    final conMod = ((constitution - 10) / 2).floor();
    final traitBonus = calculateHpBonusFromTraits(traits, allTraits);
    final featBonus = calculateHpBonusFromFeats(feats, allFeats);
    final hpPerLevel = 8 + conMod + traitBonus + featBonus;
    return hpPerLevel < 1 ? 1 : hpPerLevel;
  }

  /// Award XP to a character
  /// Returns true if character is now eligible for level up
  Future<bool> awardXp(int characterId, int amount) async {
    final char = await _dao.getCharacterById(characterId);
    if (char == null) return false;

    final newXp = char.xp + amount;
    await _dao.updateXp(characterId, newXp);

    // Check if eligible for level up
    final nextLevelXp = XpThresholds.xpForLevel(char.level + 1);
    return newXp >= nextLevelXp;
  }

  /// Check if character is eligible for level up
  Future<bool> isLevelUpAvailable(int characterId) async {
    final char = await _dao.getCharacterById(characterId);
    if (char == null) return false;

    final nextLevelXp = XpThresholds.xpForLevel(char.level + 1);
    return char.xp >= nextLevelXp;
  }

  /// Process level up for a character
  /// Applies level increase, HP boost, and optional attribute boosts
  Future<void> processLevelUp({
    required int characterId,
    required LevelUpChoices choices,
    required List<TraitDef> allTraits,
    required List<FeatDef> allFeats,
  }) async {
    final char = await _dao.getCharacterById(characterId);
    if (char == null) return;

    final newLevel = char.level + 1;

    // Parse character traits and feats
    List<String> traits = [];
    List<String> feats = [];
    try {
      traits = (jsonDecode(char.traits) as List).cast<String>();
    } catch (_) {}
    try {
      feats = (jsonDecode(char.feats) as List).cast<String>();
    } catch (_) {}

    // Add new feat if selected
    if (choices.selectedFeat != null && choices.selectedFeat!.isNotEmpty) {
      feats.add(choices.selectedFeat!);
    }

    // Calculate new max HP
    final newMaxHp = calculateMaxHp(
      level: newLevel,
      constitution: char.constitution,
      traits: traits,
      feats: feats,
      allTraits: allTraits,
      allFeats: allFeats,
    );

    // Build update companion
    var companion = CharacterCompanion(
      level: Value(newLevel),
      maxHp: Value(newMaxHp),
      currentHp: Value(newMaxHp), // Full heal on level up
    );

    // Apply attribute boosts every 4 levels
    if (newLevel % 4 == 0) {
      final Map<String, int> boosts = {};

      void addBoost(String? attr) {
        if (attr == null) return;
        final key = attr.toLowerCase();
        boosts[key] = (boosts[key] ?? 0) + 1;
      }

      addBoost(choices.attributeBoost1);
      addBoost(choices.attributeBoost2);

      // Apply boosts to companion
      boosts.forEach((key, value) {
        switch (key) {
          case 'strength':
          case 'str':
            companion =
                companion.copyWith(strength: Value(char.strength + value));
            break;
          case 'dexterity':
          case 'dex':
            companion =
                companion.copyWith(dexterity: Value(char.dexterity + value));
            break;
          case 'constitution':
          case 'con':
            companion = companion.copyWith(
                constitution: Value(char.constitution + value));
            break;
          case 'intelligence':
          case 'int':
            companion = companion.copyWith(
                intelligence: Value(char.intelligence + value));
            break;
          case 'wisdom':
          case 'wis':
            companion = companion.copyWith(wisdom: Value(char.wisdom + value));
            break;
          case 'charisma':
          case 'cha':
            companion =
                companion.copyWith(charisma: Value(char.charisma + value));
            break;
        }
      });
    }

    // Update feats if new one was added
    if (choices.selectedFeat != null && choices.selectedFeat!.isNotEmpty) {
      companion = companion.copyWith(feats: Value(jsonEncode(feats)));
    }

    await (db.update(db.character)..where((t) => t.id.equals(characterId)))
        .write(companion);
  }

  /// Get reference to the database for direct updates
  AppDatabase get db => _dao.attachedDatabase;
}
