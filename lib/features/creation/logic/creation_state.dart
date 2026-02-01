import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

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
    this.excludedSpecies = const {},
    this.isMagicEnabled = false,
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
    Set<String>? excludedSpecies,
    bool? isMagicEnabled,
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
      excludedSpecies: excludedSpecies ?? this.excludedSpecies,
      isMagicEnabled: isMagicEnabled ?? this.isMagicEnabled,
    );
  }

  CreationBudgets get budgets {
    switch (difficulty) {
      case GameDifficulty.easy:
        return const CreationBudgets(
            pointBuyPoints: 42,
            originSkills: 4,
            originFeats: 2,
            traitPoints: 6,
            maxAttribute: 18);
      case GameDifficulty.medium:
        return const CreationBudgets(
            pointBuyPoints: 28,
            originSkills: 3,
            originFeats: 1,
            traitPoints: 3,
            maxAttribute: 18);
      case GameDifficulty.hard:
        return const CreationBudgets(
            pointBuyPoints: 19,
            originSkills: 2,
            originFeats: 0,
            traitPoints: 1,
            maxAttribute: 18);
      case GameDifficulty.expert:
        return const CreationBudgets(
            pointBuyPoints: 12,
            originSkills: 1,
            originFeats: 0,
            traitPoints: 1,
            maxAttribute: 18);
      case GameDifficulty.custom:
        return const CreationBudgets(
            pointBuyPoints: 999,
            originSkills: 99,
            originFeats: 99,
            traitPoints: 99,
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

  void setOrigin(OriginDef origin, FeatDef originFeat) {
    final newSkillRanks = Map<String, int>.from(state.skillRanks);
    final newFeats = List<FeatDef>.from(state.selectedFeats);

    if (state.selectedOrigin != null) {
      // Logic to clear old origin effects could go here, but for MVP we assume forward progression
    }

    // Add new skills
    for (var skillName in origin.skills) {
      newSkillRanks[skillName] = 1;
    }

    // Add new Feat
    if (!newFeats.any((f) => f.name == originFeat.name)) {
      newFeats.add(originFeat);
    }

    state = state.copyWith(
      selectedOrigin: origin,
      skillRanks: newSkillRanks,
      selectedFeats: newFeats,
    );
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

  bool hasFeat(String featName) {
    return state.selectedFeats.any((f) => f.name == featName);
  }

  bool hasTrait(String traitName) {
    return state.selectedTraits.any((t) => t.name == traitName);
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
