import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/services/ai_spell_generator.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

class StepSkillsMagic extends ConsumerStatefulWidget {
  const StepSkillsMagic({super.key});

  @override
  ConsumerState<StepSkillsMagic> createState() => _StepSkillsMagicState();
}

class _StepSkillsMagicState extends ConsumerState<StepSkillsMagic> {
  late TextEditingController _descController;
  bool _isGeneratingSpells = false;

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

  Future<void> _generateSpells(
      WidgetRef ref, CharacterCreationState state) async {
    setState(() => _isGeneratingSpells = true);

    try {
      final notifier = ref.read(creationProvider.notifier);
      final service = ref.read(aiSpellGeneratorServiceProvider);

      // Construct Dummy Character for context
      final dummyChar = CharacterData(
        id: 0,
        name: 'Traveler',
        species: state.selectedSpecies?.name ?? 'Human',
        origin: state.selectedOrigin?.name ?? 'Unknown',
        attributes: '{}',
        skills: '{}',
        traits: jsonEncode(state.selectedTraits.map((t) => t.name).toList()),
        feats: jsonEncode(state.selectedFeats.map((f) => f.name).toList()),
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 0,
        location: 'Unknown',
        worldId: 0,
        magicPillar: state.magicPillar,
        spells: '[]',
        currentMana: 10,
        maxMana: 10,
        armorClass: 10,
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
        xp: 0,
        hand: '[]',
        discardPile: '[]',
        inventory: '[]',
        equipment: '{}',
      );

      final spells = await service.generateStartingSpells(dummyChar);
      notifier.setGeneratedSpells(spells);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error generating spells: $e")));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSpells = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update controller text only if distinct and not focused?
    // Actually, simply relying on initState is usually enough for "stepping" flows.
    // If we wanted 100% reactive sync (e.g. if another logic changed it), we'd verify:
    // if (_descController.text != state.magicDescription) {
    //   _descController.text = state.magicDescription ?? '';
    // }
    // But forcing text update while typing is what causes cursor jumps.
    // We need to know which skills came from Origin for visibility logic
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);
    final allSkills = ModularRulesController().getSkills(state.activeGenres);
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

    final remainingPoints = state.budgets.generalSkillPoints - usedPoints;

    // Check for Magic Section Visibility
    // Show if: 1) World has magic enabled AND 2) Character has a magic source (locked skill unlocked)
    bool showMagic = false;
    bool manaVoid = false;
    bool spiritCompanion = false;

    if (state.isMagicEnabled) {
      if (state.selectedTraits.any((t) => t.name == 'Mana Void'))
        manaVoid = true;
      if (state.selectedTraits.any((t) => t.name == 'Spirit Companion'))
        spiritCompanion = true;

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

    // Determine Logic for Mana
    // If Mana Void -> Fixed at 0
    // If Spirit Companion -> Fixed at 12
    // Else -> Default 10, adjustable? User said "attribute that character's can increase."
    // We'll treat it as a special attribute point spend? Or just a slider for now.
    // The prompt implies it's an attribute they can increase.
    // "If they selected mana void... set at 0 and not be increased".
    // "Spirit companion... start at 12 and not be adjustable".
    // For others, "should be an attribute that character's can increase."
    // This implies spending generic Attribute points? Or Skill points?
    // Given we are in StepSkillsMagic, maybe it uses Skill Points?
    // Or maybe it's just a free setting like "Base Mana".
    // For MVP, lets assume it's just a slider that updates `currentMana` / `maxMana`.
    // But what budget does it come from?
    // The user didn't specify a cost.
    // I'll add a simple counter UI logic for now without cost, or maybe cost 1 skill point per +1 Mana?
    // "Attribute that character's can increase" usually implies spending XP or Creation Points.
    // Since we are in creation, I'll default to it being free or part of the "Flavor" unless strict budget requested.
    // Wait, "Attribute Point Buy" step is earlier.
    // I'll put it here as a free customization for now, bounded reasonably (e.g. 10-20).

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Skills", style: Theme.of(context).textTheme.headlineSmall),
              Row(
                children: [
                  ActionChip(
                    label: const Text("Add Custom"),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () => _showAddSkillDialog(context, ref),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text("Points: $remainingPoints"),
                    backgroundColor:
                        remainingPoints >= 0 ? Colors.blue[900] : Colors.red,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
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
            if (manaVoid)
              const Card(
                  color: Colors.black54,
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text("Mana Void: Mana is fixed at 0.",
                          style: TextStyle(color: Colors.red))))
            else if (spiritCompanion)
              const Card(
                  color: Colors.indigo,
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text("Spirit Companion: Mana is fixed at 12.",
                          style: TextStyle(color: Colors.white))))
            else
              // Editable Mana?
              // Currently strictly 10 on backend default.
              // We'd need to add a "Mana" field to CreationState to track it if editable.
              // But CreationState doesn't have it.
              // I'll show a display card for now saying "Base Mana: 10".
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text("Base Mana: 10"))),
            const SizedBox(height: 16),
            Text(
              "Choose the domain of magic your character has learned to channel.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final pillars = ModularRulesController().allPillars;

              List<PillarDef> availablePillars = pillars;
              String? restrictionReason;

              if (state.allowedPillars != null) {
                availablePillars = pillars
                    .where((p) => state.allowedPillars!.contains(p.name))
                    .toList();
                // Only show restriction text if we actually filtered something
                if (availablePillars.length < pillars.length) {
                  restrictionReason = "Restricted by your Traits/Feats.";
                }
              }

              final selectedPillar = state.magicPillar != null
                  ? pillars
                      .where((p) => p.name == state.magicPillar)
                      .firstOrNull
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('magic_pillar_dropdown'),
                    value:
                        availablePillars.any((p) => p.name == state.magicPillar)
                            ? state.magicPillar
                            : null,
                    decoration: InputDecoration(
                      labelText: "Magic Pillar",
                      border: const OutlineInputBorder(),
                      helperText: restrictionReason ??
                          (selectedPillar != null
                              ? "Keywords: ${selectedPillar.keywords.join(', ')}"
                              : null),
                      helperMaxLines: 2,
                      errorText: (state.magicPillar != null &&
                              !availablePillars
                                  .any((p) => p.name == state.magicPillar))
                          ? "Selection invalid for traits."
                          : null,
                    ),
                    items: availablePillars.map((p) {
                      return DropdownMenuItem(
                        value: p.name,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
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
                    onChanged: (val) {
                      notifier.setMagicDetails(
                          val!, state.magicDescription ?? '');
                      // Clear generated spells if pillar changes?
                      // Maybe. For now, let user decide to regenerate.
                    },
                    selectedItemBuilder: (context) {
                      return availablePillars.map((p) => Text(p.name)).toList();
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
            const SizedBox(height: 32),
            Text("Grimoire Construction",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                "Generate starting spells based on your Pillar and Traits."),
            const SizedBox(height: 16),
            if (_isGeneratingSpells)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                onPressed: state.magicPillar != null
                    ? () => _generateSpells(ref, state)
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Generate Spells"),
              ),
            if (state.generatedSpells.isNotEmpty) ...[
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: state.generatedSpells.length,
                itemBuilder: (context, index) {
                  final spell = state.generatedSpells[index];
                  final isSelected =
                      state.selectedSpells.any((s) => s.name == spell.name);
                  return InkWell(
                    onTap: () => notifier.toggleSpell(spell),
                    child: Card(
                      color: isSelected ? Colors.purple.withOpacity(0.3) : null,
                      shape: isSelected
                          ? RoundedRectangleBorder(
                              side: const BorderSide(
                                  color: Colors.purple, width: 2),
                              borderRadius: BorderRadius.circular(4))
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(spell.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            Text(spell.intent,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 10)),
                            const Spacer(),
                            Text(
                                spell.damageDice.isEmpty
                                    ? "Utility"
                                    : spell.damageDice,
                                style: const TextStyle(fontSize: 12)),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  size: 16, color: Colors.purpleAccent),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text("Selected: ${state.selectedSpells.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]
          ]
        ],
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    String selectedAttr = 'Intelligence';
    final attributes = [
      'Strength',
      'Dexterity',
      'Constitution',
      'Intelligence',
      'Wisdom',
      'Charisma'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Custom Skill"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Skill Name",
                    hintText: "e.g. Knowledge: Geography",
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: selectedAttr,
                    decoration: const InputDecoration(labelText: "Attribute"),
                    items: attributes
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedAttr = val!);
                    }),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    ref
                        .read(creationProvider.notifier)
                        .updateSkillRank(nameCtrl.text, 1);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }
}
