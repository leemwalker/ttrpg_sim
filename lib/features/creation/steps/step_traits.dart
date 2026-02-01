import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepTraits extends ConsumerWidget {
  const StepTraits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);
    final allTraits = ModularRulesController().getTraits(state.activeGenres);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Select Traits",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (state.difficulty != GameDifficulty.custom)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: state.remainingTraitPoints >= 0
                      ? Colors.blue[900]
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Text(
                  "Points: ${state.remainingTraitPoints}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              )
            else
              const Text("Sandbox Mode (Unlimited)",
                  style: TextStyle(color: Colors.amber)),
          ],
        ),
        const SizedBox(height: 8),
        if (state.difficulty != GameDifficulty.custom)
          Text(
              "Budget: ${state.budgets.traitPoints} Starting Points. Positive Cost consumes points, Negative updates refund."),
        const SizedBox(height: 16),
        ...allTraits.map((trait) {
          final isSelected =
              state.selectedTraits.any((t) => t.name == trait.name);

          // Determine if we can afford it (if not selected)
          final canAfford =
              trait.cost <= 0 || state.remainingTraitPoints >= trait.cost;

          return Card(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : null,
            shape: isSelected
                ? RoundedRectangleBorder(
                    side: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    title: Text("${trait.name} (${trait.cost} pts)"),
                    subtitle: Text(trait.description),
                    trailing: ElevatedButton(
                      onPressed: (isSelected || canAfford)
                          ? () => notifier.toggleTrait(trait)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.redAccent
                            : (canAfford ? Colors.green : Colors.grey),
                      ),
                      child: Text(isSelected ? "Remove" : "Add"),
                    ),
                  ),
                  if (trait.effect.isNotEmpty && trait.effect != 'None')
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Effect: ${trait.effect}",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.white70)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
