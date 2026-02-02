import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/core/models/rules/spell_model.dart';

class CharacterCreationState {
  final List<String> activeGenres;
  final GameDifficulty difficulty;
  final SpeciesDef? selectedSpecies;
  final OriginDef? selectedOrigin;
  final List<TraitDef> selectedTraits;

  // Attributes: Key is Attribute Name, Value is Score (e.g., 10)
  final Map<String, int> attributes;

  // Skill Ranks: Key is Skill Name, Value is Rank (0, 1, 2)
  final Map<String, int> skillRanks;

  final List<FeatDef> selectedFeats;

  final int skillPointsBudget; // Start with 3

  final String? magicPillar;
  final String? magicDescription;

  final Set<String> excludedSpecies; // Names of species to hide
  final bool isMagicEnabled; // From World settings
  final List<SpeciesDef> customSpecies; // From World Config

  final Set<String>?
      allowedPillars; // If null, all allowed (or none if not magic enabled?). Let's say null = all/generic. Empty = none?

  final List<SpellDef> generatedSpells;
  final List<SpellDef> selectedSpells;

  CharacterCreationState({
    required this.activeGenres,
    this.difficulty = GameDifficulty.medium,
    this.selectedSpecies,
    this.selectedOrigin,
    this.selectedTraits = const [],
    this.attributes = const {}, // Initialize empty or with base values
    this.skillRanks = const {},
    this.selectedFeats = const [],
    this.skillPointsBudget = 3,
    this.magicPillar,
    this.magicDescription,
    this.allowedPillars,
    this.excludedSpecies = const {},
    this.isMagicEnabled = false,
    this.customSpecies = const [],
    this.generatedSpells = const [],
    this.selectedSpells = const [],
  });

  CharacterCreationState copyWith({
    List<String>? activeGenres,
    GameDifficulty? difficulty,
    SpeciesDef? selectedSpecies,
    OriginDef? selectedOrigin,
    List<TraitDef>? selectedTraits,
    Map<String, int>? attributes,
    Map<String, int>? skillRanks,
    List<FeatDef>? selectedFeats,
    int? skillPointsBudget,
    String? magicPillar,
    String? magicDescription,
    Set<String>? allowedPillars,
    bool forceNullAllowedPillars = false,
    Set<String>? excludedSpecies,
    bool? isMagicEnabled,
    List<SpeciesDef>? customSpecies,
    List<SpellDef>? generatedSpells,
    List<SpellDef>? selectedSpells,
  }) {
    return CharacterCreationState(
      activeGenres: activeGenres ?? this.activeGenres,
      difficulty: difficulty ?? this.difficulty,
      selectedSpecies: selectedSpecies ?? this.selectedSpecies,
      selectedOrigin: selectedOrigin ?? this.selectedOrigin,
      selectedTraits: selectedTraits ?? this.selectedTraits,
      attributes: attributes ?? this.attributes,
      skillRanks: skillRanks ?? this.skillRanks,
      selectedFeats: selectedFeats ?? this.selectedFeats,
      skillPointsBudget: skillPointsBudget ?? this.skillPointsBudget,
      magicPillar: magicPillar ?? this.magicPillar,
      magicDescription: magicDescription ?? this.magicDescription,
      allowedPillars: forceNullAllowedPillars
          ? null
          : (allowedPillars ?? this.allowedPillars),
      excludedSpecies: excludedSpecies ?? this.excludedSpecies,
      isMagicEnabled: isMagicEnabled ?? this.isMagicEnabled,
      customSpecies: customSpecies ?? this.customSpecies,
      generatedSpells: generatedSpells ?? this.generatedSpells,
      selectedSpells: selectedSpells ?? this.selectedSpells,
    );
  }

  // ... (budgets and remainingTraitPoints getters stay same)
  CreationBudgets get budgets {
    switch (difficulty) {
      case GameDifficulty.easy:
        return const CreationBudgets(
            pointBuyPoints: 42,
            originSkills: 4,
            originFeats: 3,
            traitPoints: 6,
            generalSkillPoints: 12,
            maxAttribute: 18);
      case GameDifficulty.medium:
        return const CreationBudgets(
            pointBuyPoints: 28,
            originSkills: 3,
            originFeats: 2,
            traitPoints: 3,
            generalSkillPoints: 6,
            maxAttribute: 18);
      case GameDifficulty.hard:
        return const CreationBudgets(
            pointBuyPoints: 19,
            originSkills: 2,
            originFeats: 1,
            traitPoints: 1,
            generalSkillPoints: 3,
            maxAttribute: 18);
      case GameDifficulty.expert:
        return const CreationBudgets(
            pointBuyPoints: 12,
            originSkills: 1,
            originFeats: 0,
            traitPoints: 1,
            generalSkillPoints: 1,
            maxAttribute: 18);
      case GameDifficulty.custom:
        return const CreationBudgets(
            pointBuyPoints: 999,
            originSkills: 99,
            originFeats: 99,
            traitPoints: 99,
            generalSkillPoints: 99,
            maxAttribute: 30);
    }
  }

  int get remainingTraitPoints {
    if (difficulty == GameDifficulty.custom) return 99; // Infinite
    // Budget - Cost of selected traits
    // Positive cost reduces budget, Negative cost increases it.
    int spent = 0;
    for (var t in selectedTraits) {
      spent += t.cost;
    }
    return budgets.traitPoints - spent;
  }
}

class CreationNotifier extends Notifier<CharacterCreationState> {
  @override
  CharacterCreationState build() {
    return CharacterCreationState(activeGenres: []);
  }

  // ... (other methods)

  void setCustomSpecies(List<SpeciesDef> species) {
    state = state.copyWith(customSpecies: species);
  }

  void toggleSpeciesExclusion(String speciesName) {
    final newExcluded = Set<String>.from(state.excludedSpecies);
    if (newExcluded.contains(speciesName)) {
      newExcluded.remove(speciesName);
    } else {
      newExcluded.add(speciesName);
    }
    state = state.copyWith(excludedSpecies: newExcluded);
  }

  void setDifficulty(GameDifficulty difficulty) {
    // When difficulty changes, we might need to reset selected traits if they exceed new budget,
    state = state.copyWith(difficulty: difficulty);
  }

  void setGenres(List<String> genres) {
    state = state.copyWith(activeGenres: genres);
  }

  void setMagicEnabled(bool enabled) {
    state = state.copyWith(isMagicEnabled: enabled);
  }

  void setSpecies(SpeciesDef species) {
    state = state.copyWith(selectedSpecies: species);
  }

  void setOrigin(OriginDef origin, List<FeatDef> originFeats) {
    final newSkillRanks = Map<String, int>.from(state.skillRanks);
    final newFeats = List<FeatDef>.from(state.selectedFeats);

    if (state.selectedOrigin != null) {
      // Logic to clear old origin effects could go here, but for MVP we assume forward progression
    }

    // Add new skills
    for (var skillName in origin.skills) {
      newSkillRanks[skillName] = 1;
    }

    // Add new Feats
    for (var feat in originFeats) {
      if (!newFeats.any((f) => f.name == feat.name)) {
        newFeats.add(feat);
      }
    }

    state = state.copyWith(
      selectedOrigin: origin,
      skillRanks: newSkillRanks,
      selectedFeats: newFeats,
    );
    _recalculateAllowedPillars();
  }

  void toggleTrait(TraitDef trait) {
    final currentTraits = List<TraitDef>.from(state.selectedTraits);
    final currentPoints = state.remainingTraitPoints;

    if (state.difficulty != GameDifficulty.custom) {
      if (!currentTraits.any((t) => t.name == trait.name)) {
        // Adding
        if (trait.cost > 0 && currentPoints < trait.cost) {
          // Cannot afford
          return;
        }
      }
    }

    if (currentTraits.any((t) => t.name == trait.name)) {
      currentTraits.removeWhere((t) => t.name == trait.name);
    } else {
      currentTraits.add(trait);
    }

    state = state.copyWith(
      selectedTraits: currentTraits,
    );
    _recalculateAllowedPillars();
  }

  void updateAttribute(String name, int value) {
    final newAttributes = Map<String, int>.from(state.attributes);
    newAttributes[name] = value;
    state = state.copyWith(attributes: newAttributes);
  }

  void updateSkillRank(String skillName, int rank) {
    if (rank < 0 || rank > 2) return;

    final newSkillRanks = Map<String, int>.from(state.skillRanks);

    if (rank == 0) {
      newSkillRanks.remove(skillName);
    } else {
      newSkillRanks[skillName] = rank;
    }

    state = state.copyWith(skillRanks: newSkillRanks);
  }

  void setMagicDetails(String pillar, String description) {
    state = state.copyWith(magicPillar: pillar, magicDescription: description);
  }

  void setGeneratedSpells(List<SpellDef> spells) {
    state = state.copyWith(generatedSpells: spells, selectedSpells: []);
  }

  void toggleSpell(SpellDef spell) {
    final current = List<SpellDef>.from(state.selectedSpells);
    if (current.any((s) => s.name == spell.name)) {
      current.removeWhere((s) => s.name == spell.name);
    } else {
      current.add(spell);
    }
    state = state.copyWith(selectedSpells: current);
  }

  bool hasFeat(String featName) {
    return state.selectedFeats.any((f) => f.name == featName);
  }

  bool hasTrait(String traitName) {
    return state.selectedTraits.any((t) => t.name == traitName);
  }

  void _recalculateAllowedPillars() {
    // 1. Collect all magic-related effects
    final allEffects = [
      ...state.selectedTraits.map((t) => t.effect),
      ...state.selectedFeats.map((f) => f.effect),
    ];

    // 2. Check for Magic Unlocks
    // Keywords: "Unlock Magic", "Unlock Pillar", "Pillar:"
    // If we have "Unlock Magic" WITHOUT "Pillar:", it's Generic -> All Allowed (return null).

    // However, "Unlock Magic (Pillar: Cosmos)" is a single string.
    // So we check if there is ANY effect that unlocks magic but DOES NOT specify a pillar.
    // Heuristic: contains "Unlock Magic" and does not contain "Pillar:" ?
    // Or maybe "Unlock Magic" is the key.

    bool hasGenericUnlock = false;
    final specificPillars = <String>{};
    for (var effect in allEffects) {
      final hasUnlock =
          effect.contains('Unlock Magic') || effect.contains('Unlock Power');
      final hasPillar = effect.contains('Pillar:');

      if (hasPillar) {
        // Parse specific
        final match = RegExp(r'Pillar:\s*([^).]+)').firstMatch(effect);
        if (match != null) {
          final parts = match.group(1)!.split('/');
          for (var p in parts) {
            specificPillars.add(p.trim());
          }
        }
      }

      if (hasUnlock && !hasPillar) {
        // Generic unlock found
        hasGenericUnlock = true;
      }
    }

    if (hasGenericUnlock) {
      // Generic overrides specific restrictions -> All allowed.
      state = state.copyWith(forceNullAllowedPillars: true); // Null means all
    } else if (specificPillars.isNotEmpty) {
      // Only specific allowed
      state = state.copyWith(allowedPillars: specificPillars);

      // If current selection is invalid, clear it?
      if (state.magicPillar != null &&
          !specificPillars.contains(state.magicPillar)) {
        state = state.copyWith(magicPillar: null);
      }
    } else {
      // No magic unlocked?
      // If visibility depends on this, we might want to signal "None".
      // But typically if no magic, the section is hidden anyway.
      // We'll set allowedPillars to empty set logic if that helps, or null.
      // Let's default to null (all) but relies on visibility check.
      // actually, let's strictly clear it if no magic found to be safe.
      state = state.copyWith(forceNullAllowedPillars: true);
    }
  }

  Map<String, int> get totalAttributes {
    final base = state.attributes;
    final species = state.selectedSpecies;

    if (species == null) return Map<String, int>.from(base);

    final total = Map<String, int>.from(base);

    species.stats.forEach((key, value) {
      if (key == 'ALL') {
        for (var k in [
          'Strength',
          'Dexterity',
          'Constitution',
          'Intelligence',
          'Wisdom',
          'Charisma'
        ]) {
          if (total.containsKey(k)) {
            total[k] = (total[k] ?? 0) + value;
          } else {
            total[k] = 8 + value;
          }
        }
      } else {
        total[key] = (total[key] ?? 8) + value;
      }
    });

    return total;
  }
}

final creationProvider =
    NotifierProvider<CreationNotifier, CharacterCreationState>(() {
  return CreationNotifier();
});
