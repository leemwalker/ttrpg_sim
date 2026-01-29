import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

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
          // Map CustomTrait to SpeciesDef
          // Assuming defaults for stats/traits as they may be empty or text
          // We could parse JSON here if implemented, for now use safe defaults/parsing
          // t.stats and t.abilities are nullable Strings

          final Map<String, int> stats = {};
          // TODO: Parse t.stats if JSON

          List<String> freeTraits = [];
          // TODO: Parse t.abilities if JSON or comma list
          // Simple comma split for now if text
          if (t.abilities != null && t.abilities!.isNotEmpty) {
            freeTraits = t.abilities!.split(',').map((e) => e.trim()).toList();
          }

          return SpeciesDef(
            name: t.name,
            genre: 'Custom', // Treat as Custom or Universal
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Species",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (allSpecies.isEmpty) const Text("No species available."),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allSpecies.length,
                itemBuilder: (context, index) {
                  final species = allSpecies[index];
                  final isSelected =
                      state.selectedSpecies?.name == species.name;

                  return Card(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : null,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: isSelected
                        ? RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2),
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
                            Text(
                                "Free Traits: ${species.freeTraits.join(', ')}"),
                        ],
                      ),
                      onTap: () {
                        ref.read(creationProvider.notifier).setSpecies(species);
                      },
                      trailing:
                          isSelected ? const Icon(Icons.check_circle) : null,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
