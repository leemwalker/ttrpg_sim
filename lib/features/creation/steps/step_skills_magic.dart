import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepSkillsMagic extends ConsumerStatefulWidget {
  const StepSkillsMagic({super.key});

  @override
  ConsumerState<StepSkillsMagic> createState() => _StepSkillsMagicState();
}

class _StepSkillsMagicState extends ConsumerState<StepSkillsMagic> {
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(creationProvider);
    _descController = TextEditingController(text: state.magicDescription);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);
    final allSkills = ModularRulesController().getSkills(state.activeGenres);

    // Update controller text only if distinct and not focused?
    // Actually, simply relying on initState is usually enough for "stepping" flows.
    // If we wanted 100% reactive sync (e.g. if another logic changed it), we'd verify:
    // if (_descController.text != state.magicDescription) {
    //   _descController.text = state.magicDescription ?? '';
    // }
    // But forcing text update while typing is what causes cursor jumps.
    // We need to know which skills came from Origin for visibility logic
    final originSkills = state.selectedOrigin?.skills ?? [];

    // Filter Skills
    final visibleSkills = allSkills.where((skill) {
      if (!skill.isLocked) return true;
      // Check if granted by Origin
      if (originSkills.contains(skill.name)) return true;
      // Check if unlocked by Feat or Trait
      // Heuristic: Effect contains Skill Name OR generic "Magic/Power/Spell/Psionic"
      final unlockedByFeat = state.selectedFeats.any((f) {
        final effect = f.effect.toLowerCase();
        return effect.contains(skill.name.toLowerCase()) ||
            effect.contains('unlock magic') ||
            effect.contains('unlock power');
      });
      final unlockedByTrait = state.selectedTraits.any((t) {
        final effect = t.effect.toLowerCase();
        return effect.contains(skill.name.toLowerCase()) ||
            effect.contains('unlock magic') ||
            effect.contains('unlock power');
      });
      return unlockedByFeat || unlockedByTrait;
    }).toList();

    // Sort skills alphabetically per request
    visibleSkills.sort((a, b) => a.name.compareTo(b.name));

    int usedPoints = 0;
    state.skillRanks.forEach((skillName, rank) {
      if (rank == 0) return;

      final bool isOrigin = originSkills.contains(skillName);

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
    // Show if: 1) World has magic enabled AND 2) Character has a magic source (locked skill unlocked)
    bool showMagic = false;
    if (state.isMagicEnabled) {
      for (var skill in visibleSkills) {
        final name = skill.name.toLowerCase();
        final isMagicSkill = name.contains('spell') ||
            name.contains('magic') ||
            name.contains('power') ||
            name.contains('exorcism') ||
            name.contains('psionic');

        if (isMagicSkill && (state.skillRanks[skill.name] ?? 0) > 0) {
          showMagic = true;
          break;
        }
      }
    }

    return Column(
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
          const int upgradeCost = 1;

          final bool canUpgrade =
              currentRank < 2 && remainingPoints >= upgradeCost;
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
                    key: ValueKey('skill_remove_${skill.name}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: canUpgrade
                        ? () => notifier.updateSkillRank(
                            skill.name, currentRank + 1)
                        : null,
                    key: ValueKey('skill_add_${skill.name}'),
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
          const SizedBox(height: 8),
          Text(
            "Choose the domain of magic your character has learned to channel.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final pillars = ModularRulesController().allPillars;
            final selectedPillar = state.magicPillar != null
                ? pillars.where((p) => p.name == state.magicPillar).firstOrNull
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('magic_pillar_dropdown'),
                  value: state.magicPillar,
                  decoration: InputDecoration(
                    labelText: "Magic Pillar",
                    border: const OutlineInputBorder(),
                    helperText: selectedPillar != null
                        ? "Keywords: ${selectedPillar.keywords.join(', ')}"
                        : null,
                    helperMaxLines: 2,
                  ),
                  items: pillars.map((p) {
                    return DropdownMenuItem(
                      value: p.name,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            p.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => notifier.setMagicDetails(
                      val!, state.magicDescription ?? ''),
                  selectedItemBuilder: (context) {
                    return pillars.map((p) => Text(p.name)).toList();
                  },
                  isExpanded: true,
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('magic_description_field'),
            controller: _descController,
            decoration: const InputDecoration(
              labelText: "Magic Description / Flavor",
              hintText: "Describe how your magic manifests...",
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (val) =>
                notifier.setMagicDetails(state.magicPillar ?? '', val),
          ),
        ]
      ],
    );
  }
}
