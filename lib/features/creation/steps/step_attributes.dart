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
    if (score <= 8) return 0;
    if (score <= 13) return score - 8;
    if (score == 14) return 7;
    if (score == 15) return 9;
    return 0;
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

    // If state attributes are empty, we should initialize them to 8 (base).
    // But we can't easily setState during build.
    // Instead we drive the UI from state, and assume 8 if missing.
    // When user interacts, we commit to state.

    // Calculate used points
    int usedPoints = 0;
    for (var def in attributeDefs) {
      final score = state.attributes[def.name] ?? 8;
      usedPoints += _calculateCost(score);
    }
    final remainingPoints = _maxPoints - usedPoints;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
            final score = state.attributes[def.name] ?? 8;
            final costNext = _costToIncrease(score);
            final canAfford = remainingPoints >= costNext && score < 15;
            final canDecrease = score > 8;

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
                            icon: const Icon(Icons.remove_circle_outline),
                            color: canDecrease ? Colors.redAccent : Colors.grey,
                            onPressed: canDecrease
                                ? () => notifier.updateAttribute(
                                    def.name, score - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: canAfford ? Colors.greenAccent : Colors.grey,
                            onPressed: canAfford
                                ? () => notifier.updateAttribute(
                                    def.name, score + 1)
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
      ),
    );
  }
}
