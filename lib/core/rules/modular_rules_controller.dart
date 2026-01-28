import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

// Interface for loading rule data (e.g. key from Assets)
abstract class RuleDataLoader {
  Future<String> load(String path);
}

class AssetRuleDataLoader implements RuleDataLoader {
  @override
  Future<String> load(String path) => rootBundle.loadString(path);
}

class ModularRulesController {
  static final ModularRulesController _instance =
      ModularRulesController._internal();

  factory ModularRulesController() {
    return _instance;
  }

  ModularRulesController._internal();

  List<GenreDef> _genres = [];
  List<AttributeDef> _attributes = [];
  List<SkillDef> _skills = [];
  List<SpeciesDef> _species = [];
  List<TraitDef> _traits = [];
  List<OriginDef> _origins = [];
  List<FeatDef> _feats = [];
  List<ItemDef> _items = [];

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Loads rules from CSVs.
  /// [loader] can be provided for testing to mock asset loading.
  Future<void> loadRules({RuleDataLoader? loader}) async {
    // strict check? maybe allow reloading if loader is provided (for tests)
    if (_isLoaded && loader == null) return;

    final dataLoader = loader ?? AssetRuleDataLoader();

    _genres = await _loadCsv(dataLoader, 'assets/system/MobileRPG - Genres.csv',
        (row) => GenreDef.fromCsv(row));
    _attributes = await _loadCsv(
        dataLoader,
        'assets/system/MobileRPG - Attributes.csv',
        (row) => AttributeDef.fromCsv(row));
    _skills = await _loadCsv(dataLoader, 'assets/system/MobileRPG - Skills.csv',
        (row) => SkillDef.fromCsv(row));
    _species = await _loadCsv(
        dataLoader,
        'assets/system/MobileRPG - Species.csv',
        (row) => SpeciesDef.fromCsv(row));
    _traits = await _loadCsv(dataLoader, 'assets/system/MobileRPG - Traits.csv',
        (row) => TraitDef.fromCsv(row));
    _origins = await _loadCsv(
        dataLoader,
        'assets/system/MobileRPG - Origins.csv',
        (row) => OriginDef.fromCsv(row));
    _feats = await _loadCsv(dataLoader, 'assets/system/MobileRPG - Feats.csv',
        (row) => FeatDef.fromCsv(row));
    _items = await _loadCsv(dataLoader, 'assets/system/MobileRPG - Items.csv',
        (row) => ItemDef.fromCsv(row));

    _isLoaded = true;
    print(
        '✅ Modular Rules Loaded: ${_species.length} Species, ${_skills.length} Skills, ${_items.length} Items');
  }

  Future<List<T>> _loadCsv<T>(RuleDataLoader loader, String path,
      T Function(List<dynamic>) fromCsv) async {
    try {
      final data = await loader.load(path);
      // Use CsvToListConverter with allowInvalid: false to prevent errors on bad lines if possible,
      // but default is usually fine. detecting eol.
      List<List<dynamic>> rows =
          const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
              .convert(data);

      // Skip header row
      if (rows.isNotEmpty) {
        rows = rows.sublist(1);
      }

      return rows
          .map((row) {
            try {
              return fromCsv(row);
            } catch (e) {
              print('⚠️ Error parsing row in $path: $row. Error: $e');
              return null;
            }
          })
          .whereType<T>()
          .toList();
    } catch (e) {
      print('❌ Failed to load rules from $path: $e');
      return [];
    }
  }

  // -- Getters filtered by World Genre --

  bool _matchesGenre(String ruleGenre, List<String> worldGenres) {
    if (ruleGenre == 'Universal') return true;
    for (var g in worldGenres) {
      if (ruleGenre.contains(g))
        return true; // Handling "Sci-Fi/Cyber" or exact matches
    }
    return false;
  }

  List<GenreDef> getAllGenres() {
    return _genres;
  }

  List<SpeciesDef> getSpecies(List<String> worldGenres) {
    return _species.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  List<AttributeDef> getAttributes(List<String> worldGenres) {
    // Attributes often include "Universal" (Attributes.csv lines 2-7)
    // ensuring we get the Core 6 + Genre specific.
    return _attributes
        .where((e) => _matchesGenre(e.genre, worldGenres))
        .toList();
  }

  List<SkillDef> getSkills(List<String> worldGenres) {
    return _skills.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  List<TraitDef> getTraits(List<String> worldGenres) {
    return _traits.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  List<OriginDef> getOrigins(List<String> worldGenres) {
    return _origins.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  List<FeatDef> getFeats(List<String> worldGenres) {
    return _feats.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  List<ItemDef> getItems(List<String> worldGenres) {
    return _items.where((e) => _matchesGenre(e.genre, worldGenres)).toList();
  }

  // Helper to get ALL for editors/debugging
  List<SpeciesDef> get allSpecies => _species;
  List<SkillDef> get allSkills => _skills;
  // ... etc can be added if needed
}
