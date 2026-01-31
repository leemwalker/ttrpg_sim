import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepOrigin extends ConsumerWidget {
  const StepOrigin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);
    final rawOrigins = ModularRulesController().getOrigins(state.activeGenres);
    final uniqueOrigins = <String, OriginDef>{};
    for (var o in rawOrigins) {
      uniqueOrigins[o.name] = o;
    }
    final origins = uniqueOrigins.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Origin",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          "Your origin determines your starting point, skills, and unique abilities.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ...origins.map((origin) {
          final isSelected = state.selectedOrigin?.name == origin.name;

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
            child: InkWell(
              key: ValueKey('origin_option_${origin.name}'),
              onTap: () {
                // Logic: Get Feat definition to pass to provider
                // We need to find the FeatDef from the rule controller
                // The origin has the feat NAME.
                final feats =
                    ModularRulesController().getFeats(state.activeGenres);
                try {
                  final featDef = feats.firstWhere((f) => f.name == origin.feat,
                      orElse: () => feats.firstWhere((f) => f.name == 'Error',
                          orElse: () => feats.first)); // Falback?
                  // Ideally we should handle if feat not found, but rules should be consistent.

                  ref
                      .read(creationProvider.notifier)
                      .setOrigin(origin, featDef);
                } catch (e) {
                  // Feat not found logic
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Error: Feat '${origin.feat}' not found in rules.")));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(origin.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                    const Divider(),
                    Text(origin.description),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text("Grants Feat: ${origin.feat}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.school,
                            size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("Skills: ${origin.skills.join(', ')}")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
