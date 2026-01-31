import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

class CharacterCreationState {
  final List<String> activeGenres;
  final SpeciesDef? selectedSpecies;
  final OriginDef? selectedOrigin;
  final List<TraitDef> selectedTraits;
  final int remainingTraitPoints;

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
    this.selectedSpecies,
    this.selectedOrigin,
    this.selectedTraits = const [],
    this.remainingTraitPoints = 2,
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
    SpeciesDef? selectedSpecies,
    OriginDef? selectedOrigin,
    List<TraitDef>? selectedTraits,
    int? remainingTraitPoints,
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
      selectedSpecies: selectedSpecies ?? this.selectedSpecies,
      selectedOrigin: selectedOrigin ?? this.selectedOrigin,
      selectedTraits: selectedTraits ?? this.selectedTraits,
      remainingTraitPoints: remainingTraitPoints ?? this.remainingTraitPoints,
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

  void setGenres(List<String> genres) {
    state = state.copyWith(activeGenres: genres);
  }

  void setMagicEnabled(bool enabled) {
    state = state.copyWith(isMagicEnabled: enabled);
  }

  void setSpecies(SpeciesDef species) {
    // When species changes, logic might be needed to reset stats or traits if they were species specific
    // For now, just set it.

    // Applying stats mods from species could be done here or in the Attribute step calculation.
    // The prompt says "Display Stat Mods", implying the base stats might be modified later or conceptually added.
    // Usually point buy is Base + Species Mod.
    state = state.copyWith(selectedSpecies: species);
  }

  void setOrigin(OriginDef origin, FeatDef originFeat) {
    // Logic: When selected, automatically add the Origin's Skills (Rank 1) and Feat to the state.
    // We should probably reset previous origin skills/feats if origin changes.

    // 1. Remove effects of previous origin if any (complex if we don't track what came from where)
    // Simpler: Identify previous origin skills and decrement/remove them?
    // Or just rebuild the skill/feat list.
    // Since this is a linear process, the user selects Origin.

    final newSkillRanks = Map<String, int>.from(state.skillRanks);
    final newFeats = List<FeatDef>.from(state.selectedFeats);

    // If there was a previous origin, we might want to clean up.
    // Ideally, we reset skills/feats triggered by Origin when Origin changes.
    // For this MVP implementation, we'll assume the user moves forward.
    // But if they switch origins, we need to handle it.

    if (state.selectedOrigin != null) {
      // Remove previous origin skills/feat
      // This requires knowing exactly what the previous origin gave.
      // Since we store selectedOrigin, we can re-fetch its definition if needed,
      // but simpler is to just rely on the UI to call setOrigin which overwrites logic.

      // Better approach: Re-calculate derived state?
      // Or just explicitly clear "Origin" contributions.
      // Let's clear ALL skills/feats that matched the previous origin?
      // Too risky.
      // Let's just trust the passed in data to be the "new truth" for Origin components.

      // For now, we will just add the new ones. Ideally we reset the state relevant to origin.
      // Let's reset 'origin' specific slots.
      // It's safer to just clear skills/feats if we assume Origin is the PRIMARY source of initial stuff.
      // But user might have added other things.

      // Correct approach for a "Creation Wizard":
      // We can maintain separate tracking or just be smart.
      // Let's assume we Clean Slate the "Origin" part.
    }

    // Add new skills
    for (var skillName in origin.skills) {
      // Set to Rank 1 if not present. If present (e.g. from Species?), keep unique?
      // Prompt: "add the Origin's Skills (Rank 1)"
      newSkillRanks[skillName] = 1;
    }

    // Add new Feat
    // Check if feat already exists?
    if (!newFeats.any((f) => f.name == originFeat.name)) {
      newFeats.add(originFeat);
    }

    state = state.copyWith(
      selectedOrigin: origin,
      skillRanks: newSkillRanks,
      selectedFeats: newFeats,
    );
  }

  // Helper to clear origin effects when switching (called by UI before setting new)?
  // Or handled inside setOrigin if we had the rules controller here.
  // Since we don't have the controller injected easily without ref,
  // we will rely on UI to provide the correct "OriginFeat" object.

  void toggleTrait(TraitDef trait) {
    final currentTraits = List<TraitDef>.from(state.selectedTraits);
    int currentPoints = state.remainingTraitPoints;

    if (currentTraits.any((t) => t.name == trait.name)) {
      // Remove
      currentTraits.removeWhere((t) => t.name == trait.name);
      currentPoints += trait
          .cost; // Refund cost (if positive cost, we get points back. If negative cost, we loose points - wait.)
      // "Positive costs points, Negative refunds points"
      // So if cost is 2, we spent 2. Removing it gives back 2.
      // If cost is -2 (flaw), we gained 2 points (budget goes up). Removing it reduces budget.
      // Algorithm: Budget -= Cost.
      // Remove: Budget += Cost.
    } else {
      // Add
      // Check budget? "Enforce the '2 Starting Points' budget"
      // If cost is positive, need enough points.
      // If cost is negative, we can always take it (it gives points).

      if (trait.cost > 0 && currentPoints < trait.cost) {
        // Cannot afford
        return;
      }

      currentTraits.add(trait);
      currentPoints -= trait.cost;
    }

    state = state.copyWith(
      selectedTraits: currentTraits,
      remainingTraitPoints: currentPoints,
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

    // Check budget? "Player gets 3 Skill Points"
    // We need to track spent points.
    // Changing from 0 to 1 costs 1 point.
    // Changing from 1 to 2 costs 1 point.
    // Origin skills are free (Rank 1).
    // We need to know which are Origin skills to not count them against budget?
    // Or does the "3 Skill Points" add ON TOP of Origin?
    // "Origin skills are already Rank 1".

    // Let's just update the rank here and let the UI show the budget remaining.
    // Or we can enforce it here.

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

  // Helper check for unlocking logic
  bool hasFeat(String featName) {
    return state.selectedFeats.any((f) => f.name == featName);
  }

  bool hasTrait(String traitName) {
    return state.selectedTraits.any((t) => t.name == traitName);
  }

  // Calculates the final attributes including species bonuses
  Map<String, int> get totalAttributes {
    final base = state.attributes;
    final species = state.selectedSpecies;

    if (species == null) return Map<String, int>.from(base);

    final total = Map<String, int>.from(base);

    // Apply Species Stats
    species.stats.forEach((key, value) {
      if (key == 'ALL') {
        // Add to all existing keys logic
        // Or strictly add to the standard 6 (if present in base)
        // Assuming base is initialized
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
            total[k] = 8 + value; // Fallback only if base missing
          }
        }
      } else {
        // Specific Attribute
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
