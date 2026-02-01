import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/features/creation/widgets/point_buy_widget.dart';

class StepAttributes extends ConsumerWidget {
  const StepAttributes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);
    final notifier = ref.read(creationProvider.notifier);
    final budgets = state.budgets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Allocate your attribute points.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        PointBuyWidget(
          onStatsChanged: (stats) {
            stats.forEach((key, value) {
              notifier.updateAttribute(key, value);
            });
          },
          maxPoints: budgets.pointBuyPoints,
          maxAttribute: budgets.maxAttribute,
        ),
        const SizedBox(height: 16),
        // Display Species Bonuses if any
        if (state.selectedSpecies != null) ...[
          const Divider(),
          Text(
            "Species Bonuses:",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.amber),
          ),
          const SizedBox(height: 8),
          ...state.selectedSpecies!.stats.entries.map((e) {
            String label = e.key == 'ALL' ? 'All Attributes' : e.key;
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                "$label: ${e.value > 0 ? '+' : ''}${e.value}",
                style: const TextStyle(fontSize: 16),
              ),
            );
          }),
        ],
      ],
    );
  }
}
