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

  @override
  List<String> get availableClasses => _hitDice.keys.toList()..sort();

  @override
  List<String> get availableSpecies => [
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

  @override
  int calculateMaxHp(String characterClass, int level) {
    final hitDie = _hitDice[characterClass] ?? 8;
    // SRD Formula: (Hit Die / 2 + 1) * Level
    // At level 1, you get max hit die, then average for subsequent levels.
    // Simplified: (hitDie / 2 + 1) per level is the average.
    final avgPerLevel = (hitDie ~/ 2) + 1;
    return avgPerLevel * level;
  }
}
