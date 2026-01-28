import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepSkillsMagic extends ConsumerWidget {
  const StepSkillsMagic({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);
    final allSkills = ModularRulesController().getSkills(state.activeGenres);

    // Filter Skills
    final visibleSkills = allSkills.where((skill) {
      if (!skill.isLocked) return true;
      // Check if unlocked by Feat or Trait
      // Heuristic: Effect contains Skill Name.
      final unlockedByFeat =
          state.selectedFeats.any((f) => f.effect.contains(skill.name));
      final unlockedByTrait =
          state.selectedTraits.any((t) => t.effect.contains(skill.name));
      return unlockedByFeat || unlockedByTrait;
    }).toList();

    // Calculate spent points
    // "Player gets 3 Skill Points (plus their Origin skills are already Rank 1)."
    // So we need to separate Origin skills (free Rank 1) from purchased points.
    // If Origin gives Rank 1, does it cost 0 points? Yes.
    // If User increases from 1 -> 2, that costs 1 point.
    // If User selects a non-Origin skill 0 -> 1, that costs 1 point.

    // We need to know which skills came from Origin?
    // state.selectedOrigin.skills
    final originSkills = state.selectedOrigin?.skills ?? [];

    int usedPoints = 0;
    state.skillRanks.forEach((skillName, rank) {
      if (rank == 0) return;

      bool isOrigin = originSkills.contains(skillName);

      if (isOrigin) {
        // Origin gives free Rank 1.
        // Rank 1 -> Cost 0.
        // Rank 2 -> Cost 1.
        if (rank > 1) usedPoints += (rank - 1);
      } else {
        // Normal skill
        // Rank 1 -> 1 pt
        // Rank 2 -> 2 pts
        usedPoints += rank;
      }
    });

    final remainingPoints = state.skillPointsBudget - usedPoints;

    // Check for Magic Section Visibility
    // Show if any LOCKED skill has Rank > 0 (meaning we unlocked it and invested in it/it was granted)
    bool showMagic = false;
    for (var skill in visibleSkills) {
      if (skill.isLocked && (state.skillRanks[skill.name] ?? 0) > 0) {
        showMagic = true;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Skills", style: Theme.of(context).textTheme.headlineSmall),
              Chip(
                label: Text("Points: $remainingPoints"),
                backgroundColor:
                    remainingPoints >= 0 ? Colors.blue[900] : Colors.red,
                labelStyle: const TextStyle(color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 16),
          ...visibleSkills.map((skill) {
            final currentRank = state.skillRanks[skill.name] ?? 0;
            final isOrigin = originSkills.contains(skill.name);

            // Cost to upgrade?
            // If Rank 0 -> 1: Cost 1
            // If Rank 1 -> 2: Cost 1
            int upgradeCost = 1;

            bool canUpgrade = currentRank < 2 && remainingPoints >= upgradeCost;
            bool canDowngrade = currentRank > 0;

            // Prevent downgrading below Origin free rank?
            // "Origin skills are already Rank 1". Assuming mandatory minimum?
            if (isOrigin && currentRank <= 1) canDowngrade = false;

            return Card(
              child: ListTile(
                title: Text(skill.name),
                subtitle: Text("${skill.attribute} - ${skill.description}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Rank $currentRank",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: canDowngrade
                          ? () => notifier.updateSkillRank(
                              skill.name, currentRank - 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: canUpgrade
                          ? () => notifier.updateSkillRank(
                              skill.name, currentRank + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          if (showMagic) ...[
            const SizedBox(height: 32),
            const Divider(thickness: 2, color: Colors.purpleAccent),
            Text("Magic Expression",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.purpleAccent)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: state.magicPillar,
              decoration: const InputDecoration(
                labelText: "Magic Pillar",
                border: OutlineInputBorder(),
              ),
              items: [
                "Matter",
                "Spirit",
                "Mind",
                "Forces",
                "Life",
                "Entropy",
                "Space",
                "Time"
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) =>
                  notifier.setMagicDetails(val!, state.magicDescription ?? ''),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: state.magicDescription),
              decoration: const InputDecoration(
                labelText: "Magic Description / Flavor",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  notifier.setMagicDetails(state.magicPillar ?? '', val),
            ),
          ]
        ],
      ),
    );
  }
}
