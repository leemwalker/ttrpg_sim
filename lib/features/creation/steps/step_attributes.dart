import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepAttributes extends ConsumerStatefulWidget {
  const StepAttributes({super.key});

  @override
  ConsumerState<StepAttributes> createState() => _StepAttributesState();
}

class _StepAttributesState extends ConsumerState<StepAttributes> {
  static const int _maxPoints = 27;

  // We need to initialize the attributes map if it's empty in the state.
  @override
  void initState() {
    super.initState();
    // Defer to build or addPostFrameCallback to initialize default values if needed.
    // However, it's better to do this when activeGenres is set, OR check in build.
  }

  int _calculateCost(int score) {
    // 8: 0
    // ...
    // 13: 5
    // 14: 7
    // 15: 9
    // 16: 12 (+3)
    // 17: 15 (+3)
    // 18: 19 (+4) or just 2 pts?
    // Let's assume standard d20 point buy usually stops at 15 or 18 cost gets high.
    // If we assume a flatter cost curve as per "Update Attribute Limits" without specifying point buy math:
    // Let's stick to 2 pts for > 13 for simplicity unless specified.
    // 8->13 = 5pts
    // 14 = 7
    // 15 = 9
    // 16 = 11
    // 17 = 13
    // 18 = 15
    if (score <= 8) return 0;
    if (score <= 13) return score - 8;
    return 5 + (score - 13) * 2;
  }

  int _costToIncrease(int currentScore) {
    if (currentScore < 13) return 1;
    if (currentScore >= 13) return 2;
    return 100;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);

    // Get all attributes definitions
    final attributeDefs =
        ModularRulesController().getAttributes(state.activeGenres);

    // Calculate used points
    int usedPoints = 0;
    for (var def in attributeDefs) {
      final score = state.attributes[def.name] ?? 10; // Default 10 per request
      usedPoints += _calculateCost(score);
    }
    final remainingPoints = _maxPoints - usedPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Attributes",
                style: Theme.of(context).textTheme.headlineSmall),
            Chip(
              label: Text("Points: $remainingPoints"),
              backgroundColor:
                  remainingPoints >= 0 ? Colors.blue[900] : Colors.red,
              labelStyle: const TextStyle(color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 16),
        if (attributeDefs.isEmpty)
          const Text("No attributes defined for these genres."),
        ...attributeDefs.map((def) {
          final score = state.attributes[def.name] ?? 10; // Default 10
          final costNext = _costToIncrease(score);
          // Max 18 per request
          final canAfford = remainingPoints >= costNext && score < 18;
          final canDecrease = score > 8; // Min 8 per request

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(def.description,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$score',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: score >= 14 ? Colors.amber : Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: ValueKey('attr_remove_${def.name}'),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: canDecrease ? Colors.redAccent : Colors.grey,
                          onPressed: canDecrease
                              ? () =>
                                  notifier.updateAttribute(def.name, score - 1)
                              : null,
                        ),
                        IconButton(
                          key: ValueKey('attr_add_${def.name}'),
                          icon: const Icon(Icons.add_circle_outline),
                          color: canAfford ? Colors.greenAccent : Colors.grey,
                          onPressed: canAfford
                              ? () =>
                                  notifier.updateAttribute(def.name, score + 1)
                              : null,
                        ),
                      ],
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
