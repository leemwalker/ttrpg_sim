import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:drift/drift.dart' as drift;

class StepSpecies extends ConsumerWidget {
  const StepSpecies({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);
    // Fetch species based on active genres
    final speciesList = ModularRulesController().getSpecies(state.activeGenres);

    final dao = ref.watch(gameDaoProvider);

    return StreamBuilder<List<CustomTrait>>(
      stream: dao.watchCustomTraitsByType('Species'),
      builder: (context, snapshot) {
        final customTraits = snapshot.data ?? [];
        final customSpecies = customTraits.map((t) {
          // Parse stats using the same logic as SpeciesDef
          final Map<String, int> stats = SpeciesDef.parseStats(t.stats ?? '');

          List<String> freeTraits = [];
          if (t.abilities != null && t.abilities!.isNotEmpty) {
            freeTraits = t.abilities!.split(',').map((e) => e.trim()).toList();
          }

          return SpeciesDef(
            name: t.name,
            genre: 'Custom',
            stats: stats,
            freeTraits: freeTraits,
          );
        }).toList();

        final Map<String, SpeciesDef> uniqueSpecies = {};
        for (var s in speciesList) {
          uniqueSpecies[s.name] = s;
        }
        for (var s in customSpecies) {
          uniqueSpecies[s.name] = s;
        }
        final allSpecies = uniqueSpecies.values.toList();

        // Application of Excluded Filter
        final visibleSpecies = allSpecies
            .where((s) => !state.excludedSpecies.contains(s.name))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Select Species",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                // Add Custom Button
                IconButton.filledTonal(
                  onPressed: () => _showAddCustomDialog(context, ref),
                  icon: const Icon(Icons.add),
                  tooltip: "Add Custom Species",
                ),
                const SizedBox(width: 8),
                // Filter Button
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Filter Species"),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: allSpecies.map((s) {
                                final isExcluded =
                                    state.excludedSpecies.contains(s.name);
                                return CheckboxListTile(
                                  title: Text(s.name),
                                  value: !isExcluded, // Checked means INCLUDED
                                  onChanged: (val) {
                                    ref
                                        .read(creationProvider.notifier)
                                        .toggleSpeciesExclusion(s.name);
                                    (context as Element).markNeedsBuild();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Done"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.filter_list),
                  label: const Text("Filter"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (visibleSpecies.isEmpty)
              const Text("No species available (check filter)."),
            ...visibleSpecies.map((species) {
              final isSelected = state.selectedSpecies?.name == species.name;

              return Card(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : null,
                margin: const EdgeInsets.only(bottom: 8),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(
                            color: Theme.of(context).primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  key: ValueKey('species_option_${species.name}'),
                  title: Text(species.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Genre: ${species.genre}"),
                      Text(
                          "Stats: ${species.stats.entries.map((e) => "${e.key} ${e.value > 0 ? '+' : ''}${e.value}").join(', ')}"),
                      if (species.freeTraits.isNotEmpty)
                        Text("Free Traits: ${species.freeTraits.join(', ')}"),
                    ],
                  ),
                  onTap: () {
                    ref.read(creationProvider.notifier).setSpecies(species);
                  },
                  trailing: isSelected ? const Icon(Icons.check_circle) : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showAddCustomDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final statsCtrl = TextEditingController();
    final traitsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Custom Species"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  hintText: "e.g. Cyborg, Demigod",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: "Description",
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: statsCtrl,
                decoration: const InputDecoration(
                  labelText: "Stat Modifiers",
                  hintText: "e.g. +2 Strength; +1 Intelligence",
                  helperText: "Format: +X Attribute; +Y Attribute",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: traitsCtrl,
                decoration: const InputDecoration(
                  labelText: "Free Traits",
                  hintText: "e.g. Night Vision, Flight",
                  helperText: "Comma separated",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;

              final dao = ref.read(gameDaoProvider);
              dao.createCustomTrait(CustomTraitsCompanion(
                name: drift.Value(nameCtrl.text),
                type: const drift.Value('Species'),
                description: drift.Value(descCtrl.text),
                stats: drift.Value(statsCtrl.text),
                abilities: drift.Value(traitsCtrl.text),
              ));

              Navigator.pop(ctx);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
