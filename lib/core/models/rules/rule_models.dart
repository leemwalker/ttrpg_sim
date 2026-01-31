/// Represents a Genre definition from `Genres.csv`
class GenreDef {
  final String name;
  final String description;
  final String currency;
  final List<String> themes;

  GenreDef({
    required this.name,
    required this.description,
    required this.currency,
    required this.themes,
  });

  factory GenreDef.fromCsv(List<dynamic> row) {
    // Name,Description,Currency,Key Themes
    return GenreDef(
      name: row[0].toString(),
      description: row[1].toString(),
      currency: row[2].toString(),
      themes: _parseList(row[3].toString()),
    );
  }

  static List<String> _parseList(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).toList();
  }
}

/// Represents an Attribute definition from `Attributes.csv`
class AttributeDef {
  final String name;
  final String genre;
  final String type;
  final String description;

  AttributeDef({
    required this.name,
    required this.genre,
    required this.type,
    required this.description,
  });

  factory AttributeDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Type,Description
    return AttributeDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      type: row[2].toString(),
      description: row[3].toString(),
    );
  }
}

/// Represents a Skill definition from `Skills.csv`
class SkillDef {
  final String name;
  final String genre;
  final String attribute;
  final bool isLocked;
  final String description;

  SkillDef({
    required this.name,
    required this.genre,
    required this.attribute,
    required this.isLocked,
    required this.description,
  });

  factory SkillDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Attribute,Locked?,Description
    return SkillDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      attribute: row[2].toString(),
      isLocked: row[3].toString().toUpperCase() == 'TRUE',
      description: row[4].toString(),
    );
  }
}

/// Represents a Species definition from `Species.csv`
class SpeciesDef {
  final String name;
  final String genre;
  final Map<String, int> stats;
  final List<String> freeTraits;

  SpeciesDef({
    required this.name,
    required this.genre,
    required this.stats,
    required this.freeTraits,
  });

  factory SpeciesDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Stats,Free Traits
    return SpeciesDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      stats: parseStats(row[2].toString()),
      freeTraits: _parseList(row[3].toString()),
    );
  }

  static Map<String, int> parseStats(String raw) {
    // e.g. "+2 CHA; +1 DEX" or "+1 All Stats"
    final Map<String, int> result = {};
    if (raw.trim().isEmpty) return result;

    if (raw.contains('All Stats')) {
      // Special case for Human
      // We might handle this logically in the controller or just store it as a special key
      result['ALL'] = 1;
      return result;
    }

    final parts = raw.split(';');
    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;
      // Expected format: "+2 CHA"
      final match = RegExp(r'([+-]?\d+)\s+(\w+)').firstMatch(part);
      if (match != null) {
        final value = int.tryParse(match.group(1)!) ?? 0;
        final key = match.group(2)!;
        result[key] = value;
      }
    }
    return result;
  }

  static List<String> _parseList(String raw) {
    if (raw.isEmpty || raw.toUpperCase() == 'NONE') return [];
    // Assuming CSV parsing handles quotes, so we just split by comma if multiple traits are listed
    // Just in case they are semicolon separate, or comma.
    // Based on "Skill Expert" vs "Skill Expert (Survival)", it seems simple.
    // If there ARE multiple, they are likely comma separated.
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// Represents a Trait definition from `Traits.csv`
class TraitDef {
  final String name;
  final String type;
  final int cost;
  final String genre;
  final String description;
  final String effect;

  TraitDef({
    required this.name,
    required this.type,
    required this.cost,
    required this.genre,
    required this.description,
    required this.effect,
  });

  factory TraitDef.fromCsv(List<dynamic> row) {
    // Name,Type,Cost,Genre,Description,Effect
    return TraitDef(
      name: row[0].toString(),
      type: row[1].toString(),
      cost: int.parse(row[2].toString()),
      genre: row[3].toString(),
      description: row[4].toString(),
      effect: row[5].toString(),
    );
  }
}

/// Represents an Origin definition from `Origins.csv`
class OriginDef {
  final String name;
  final String genre;
  final List<String> skills;
  final String feat;
  final List<String> items;
  final String description;

  OriginDef({
    required this.name,
    required this.genre,
    required this.skills,
    required this.feat,
    required this.items,
    required this.description,
  });

  factory OriginDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Skills,Feat,Starting Items,Description
    return OriginDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      skills: _parseList(row[2].toString()),
      feat: row[3].toString(),
      items: _parseList(row[4].toString()),
      description: row[5].toString(),
    );
  }

  static List<String> _parseList(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).toList();
  }
}

/// Represents a Feat definition from `Feats.csv`
class FeatDef {
  final String name;
  final String genre;
  final String type;
  final String prerequisite;
  final String description;
  final String effect;

  FeatDef({
    required this.name,
    required this.genre,
    required this.type,
    required this.prerequisite,
    required this.description,
    required this.effect,
  });

  factory FeatDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Type,Prerequisite,Description,Effect
    return FeatDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      type: row[2].toString(),
      prerequisite: row[3].toString(),
      description: row[4].toString(),
      effect: row[5].toString(),
    );
  }
}

/// Represents an Item definition from `Items.csv`
class ItemDef {
  final String name;
  final String genre;
  final String type;
  final String damageDice;
  final String damageType;
  final String properties;
  final int cost;
  final String description;

  ItemDef({
    required this.name,
    required this.genre,
    required this.type,
    required this.damageDice,
    required this.damageType,
    required this.properties,
    required this.cost,
    required this.description,
  });

  factory ItemDef.fromCsv(List<dynamic> row) {
    // Name,Genre,Type,DamageDice,DamageType,Properties,Cost,Description,,,
    return ItemDef(
      name: row[0].toString(),
      genre: row[1].toString(),
      type: row[2].toString(),
      damageDice: row[3].toString(),
      damageType: row[4].toString(),
      properties: row[5].toString(),
      cost: int.parse(row[6].toString()),
      description: row[7].toString(),
    );
  }
}

/// Represents a Magic Pillar definition from `MagicPillars.csv`
class PillarDef {
  final String name;
  final String description;
  final List<String> keywords;

  PillarDef({
    required this.name,
    required this.description,
    required this.keywords,
  });

  factory PillarDef.fromCsv(List<dynamic> row) {
    // Name,Description,Keywords
    return PillarDef(
      name: row[0].toString(),
      description: row[1].toString(),
      keywords: _parseList(row[2].toString()),
    );
  }

  static List<String> _parseList(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).toList();
  }
}
