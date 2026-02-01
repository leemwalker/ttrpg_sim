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
        if (state.difficulty != GameDifficulty.custom)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Chip(
                  label: Text("Max Skills: ${state.budgets.originSkills}"),
                  backgroundColor: Colors.blue[900],
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text("Max Feats: ${state.budgets.originFeats}"),
                  backgroundColor: Colors.purple[900],
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ...origins.map((origin) {
          final isSelected = state.selectedOrigin?.name == origin.name;

          // Check budget validation
          final skillsCount = origin.skills.length;
          // Validation: Origin must not exceed budget
          // Unless Custom difficulty/Infinite
          bool valid = true;
          if (state.difficulty != GameDifficulty.custom) {
            if (skillsCount > state.budgets.originSkills) valid = false;
            // Determine if 'feat' string implies 1 feat.
            // If origin.feat is not empty, it counts as 1.
            // If budget is 0, and origin has feat, invalid.
            if (state.budgets.originFeats == 0 &&
                origin.feat.isNotEmpty &&
                origin.feat != 'None') valid = false;
          }

          return Card(
            color: valid
                ? (isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : null)
                : Colors.grey.withOpacity(0.1), // Dim if invalid
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
              onTap: valid
                  ? () {
                      final feats =
                          ModularRulesController().getFeats(state.activeGenres);
                      try {
                        final featDef = feats.firstWhere(
                            (f) => f.name == origin.feat,
                            orElse: () => feats.firstWhere(
                                (f) => f.name == 'Error', // Fallback
                                orElse: () => feats.isEmpty
                                    ? FeatDef(
                                        name: "Placeholder",
                                        genre: "",
                                        type: "",
                                        prerequisite: "",
                                        description: "",
                                        effect: "")
                                    : feats.first));

                        ref
                            .read(creationProvider.notifier)
                            .setOrigin(origin, featDef);
                      } catch (e) {
                        // Error handling
                      }
                    }
                  : null, // Disable tap if invalid
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(origin.name,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: valid ? null : Colors.grey)),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (!valid)
                          const Text("Exceeds Budget",
                              style:
                                  TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const Divider(),
                    Text(origin.description,
                        style: TextStyle(color: valid ? null : Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 16,
                            color: valid ? Colors.amber : Colors.grey),
                        const SizedBox(width: 4),
                        Text("Grants Feat: ${origin.feat}",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: valid ? null : Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school,
                            size: 16,
                            color: valid ? Colors.blueAccent : Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("Skills: ${origin.skills.join(', ')}",
                                style: TextStyle(
                                    color: valid ? null : Colors.grey))),
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
