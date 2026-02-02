import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

class StepOrigin extends ConsumerStatefulWidget {
  const StepOrigin({super.key});

  @override
  ConsumerState<StepOrigin> createState() => _StepOriginState();
}

class _StepOriginState extends ConsumerState<StepOrigin> {
  final _customNameController = TextEditingController();
  final _customDescController = TextEditingController();
  List<OriginDef>? _cachedOrigins;

  @override
  void initState() {
    super.initState();
    // Initialize controllers if custom is already selected?
    // We can't easily peek provider in initState without listen: false, but safe enough to just start empty.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize only checking once or reacting to state changes?
    // Actually, we want to maintain the cache of sampled origins so they don't change on rebuilds
    if (_cachedOrigins == null) {
      final state = ref.read(creationProvider);
      final rawOrigins =
          ModularRulesController().getOrigins(state.activeGenres);
      final uniqueOrigins = <String, OriginDef>{};
      for (var o in rawOrigins) {
        uniqueOrigins[o.name] = o;
      }
      final allOrigins = uniqueOrigins.values.toList();

      // Sampling approx 6 diverse origins
      if (allOrigins.length > 6) {
        allOrigins.shuffle();
        _cachedOrigins = allOrigins.take(6).toList();
      } else {
        _cachedOrigins = allOrigins;
      }
    }
  }

  void _onCustomChanged() {
    // Update the custom origin in the state
    final name = _customNameController.text.isEmpty
        ? "Custom Origin"
        : _customNameController.text;
    final desc = _customDescController.text;

    final customOrigin = OriginDef(
      name: name,
      genre: 'Universal',
      skills: [], // User selects manually in later steps? Or we assume empty for now.
      feat: 'None',
      items: [],
      description: desc,
    );

    // We also need a dummy feat or 'None'
    // Finding 'None' feat or creating placeholder
    final feats = ModularRulesController()
        .getFeats([]); // Empty genres ok for finding None?
    // Usually 'None' feat exists or we mock it.
    final noneFeat = FeatDef(
        name: 'None',
        genre: 'Universal',
        type: 'General',
        prerequisite: '',
        description: 'No specific feat.',
        effect: '');

    ref.read(creationProvider.notifier).setOrigin(customOrigin, noneFeat);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creationProvider);
    final origins = _cachedOrigins ?? [];

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
        ...origins
            .map((origin) => _buildOriginCard(context, ref, state, origin)),

        // Custom Origin Card
        _buildCustomOriginCard(context, ref, state),
      ],
    );
  }

  Widget _buildOriginCard(BuildContext context, WidgetRef ref,
      CharacterCreationState state, OriginDef origin) {
    final isSelected = state.selectedOrigin?.name == origin.name;

    // Check budget validation
    final skillsCount = origin.skills.length;
    bool valid = true;
    if (state.difficulty != GameDifficulty.custom) {
      if (skillsCount > state.budgets.originSkills) valid = false;
      if (state.budgets.originFeats == 0 &&
          origin.feat.isNotEmpty &&
          origin.feat != 'None') valid = false;
    }

    return Card(
      color: valid
          ? (isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : null)
          : Colors.grey.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 8),
      shape: isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
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
                  final featDef = feats.firstWhere((f) => f.name == origin.feat,
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
            : null,
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
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
              const Divider(),
              Text(origin.description,
                  style: TextStyle(color: valid ? null : Colors.grey)),
              const SizedBox(height: 8),
              if (valid) ...[
                Row(
                  children: [
                    Icon(Icons.star,
                        size: 16, color: valid ? Colors.amber : Colors.grey),
                    const SizedBox(width: 4),
                    Text("Grants Feat: ${origin.feat}",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        child: Text("Skills: ${origin.skills.join(', ')}")),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomOriginCard(
      BuildContext context, WidgetRef ref, CharacterCreationState state) {
    // Check if the selected origin is one of the cached ones. If not, and it's not null, it might be custom.
    // Or we check by name? "Custom Origin"
    final isCustomSelected = state.selectedOrigin != null &&
        _cachedOrigins?.any((o) => o.name == state.selectedOrigin!.name) ==
            false;

    // Actually, checking if name matches current custom input or flag is better,
    // but checking if NOT in cached list is a good proxy for "Custom" since cached list is static.

    return Card(
      key: const ValueKey('origin_option_custom'),
      color: isCustomSelected
          ? Theme.of(context).primaryColor.withOpacity(0.2)
          : null,
      shape: isCustomSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: () {
          _onCustomChanged(); // Set it immediately
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  const Text("Custom Origin",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (isCustomSelected)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(),
              const Text("Create your own background story."),
              if (isCustomSelected) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customNameController,
                  decoration: const InputDecoration(
                    labelText: "Origin Name",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white54,
                  ),
                  onChanged: (_) => _onCustomChanged(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customDescController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white54,
                  ),
                  maxLines: 2,
                  onChanged: (_) => _onCustomChanged(),
                ),
                const SizedBox(height: 8),
                const Text("Select Skills & Feats manually in the next steps.",
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
              ]
            ],
          ),
        ),
      ),
    );
  }
}
