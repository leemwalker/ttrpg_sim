import 'package:ttrpg_sim/core/database/database.dart';

/// Information about a character background.
class BackgroundInfo {
  final String name;
  final String featureName;
  final String featureDesc;
  final String originFeat;

  const BackgroundInfo({
    required this.name,
    required this.featureName,
    required this.featureDesc,
    required this.originFeat,
  });
}

/// Abstract class defining a pluggable RPG rules system.
abstract class RpgSystem {
  /// List of available character classes in this system.
  List<String> get availableClasses;

  /// List of available species/races in this system.
  List<String> get availableSpecies;

  /// List of available backgrounds in this system.
  List<String> get availableBackgrounds;

  /// List of available feats in this system.
  List<String> get availableFeats;

  /// Register custom traits (Species/Class/Feat) into the rules engine.
  void registerCustomTraits(List<CustomTrait> traits);

  /// Get details for a specific background.
  BackgroundInfo getBackgroundInfo(String backgroundName);

  /// Calculate max HP for a given class and level.
  /// Formula is system-specific.
  int calculateMaxHp(String characterClass, int level);

  /// Get maximum spell slots for a class at a given level.
  /// Returns a map like {"1st": 2, "2nd": 1} for casters, empty map for non-casters.
  Map<String, int> getMaxSpellSlots(String charClass, int level);

  /// Get class features available to a class at a given level.
  /// Returns features accumulated up to and including that level.
  List<String> getClassFeatures(String charClass, int level);

  /// Get known spells/cantrips for a class at a given level.
  /// MVP: Returns a default subset of iconic spells for the class.
  List<String> getKnownSpells(String charClass, int level);

  /// Get the ability modifier for a skill or ability check.
  /// For D&D 5e: (attribute_score - 10) ~/ 2
  int getModifier(CharacterData character, String checkName);
}
