/// Abstract class defining a pluggable RPG rules system.
abstract class RpgSystem {
  /// List of available character classes in this system.
  List<String> get availableClasses;

  /// List of available species/races in this system.
  List<String> get availableSpecies;

  /// Calculate max HP for a given class and level.
  /// Formula is system-specific.
  int calculateMaxHp(String characterClass, int level);
}
