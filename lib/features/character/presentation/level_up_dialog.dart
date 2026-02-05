import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/character/services/progression_service.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

class LevelUpDialog extends ConsumerStatefulWidget {
  final CharacterData character;
  const LevelUpDialog({super.key, required this.character});

  @override
  ConsumerState<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends ConsumerState<LevelUpDialog> {
  bool isLoading = true;
  bool isProcessing = false;
  List<TraitDef> allTraits = [];
  List<FeatDef> allFeats = [];
  Map<String, int> attributeBoosts = {}; // Attribute Name -> Boost Amount
  int pointsSpendable = 0;
  final int maxPoints = 2; // Fixed for now
  final int attributeCap = 20;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final traitsCsv = await rootBundle.loadString('assets/system/Traits.csv');
      final featsCsv = await rootBundle.loadString('assets/system/Feats.csv');

      final traitsList =
          const CsvToListConverter().convert(traitsCsv, eol: '\n');
      if (traitsList.isNotEmpty) traitsList.removeAt(0);
      allTraits = traitsList
          .map((row) => TraitDef.fromCsv(row))
          .toList(); // ignore: avoid_dynamic_calls

      final featsList = const CsvToListConverter().convert(featsCsv, eol: '\n');
      if (featsList.isNotEmpty) featsList.removeAt(0);
      allFeats = featsList
          .map((row) => FeatDef.fromCsv(row))
          .toList(); // ignore: avoid_dynamic_calls
    } catch (e) {
      debugPrint("Error loading system data: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading rules..."),
          ],
        ),
      );
    }

    final char = widget.character;
    final nextLevel = char.level + 1;
    final isAttributeBoost = nextLevel % 4 == 0;

    // Attribute Setup
    final attributes = {
      'Strength': char.strength,
      'Dexterity': char.dexterity,
      'Constitution': char.constitution,
      'Intelligence': char.intelligence,
      'Wisdom': char.wisdom,
      'Charisma': char.charisma,
    };

    // Calculate New HP
    // We need service to calc HP using loaded traits.
    final service = ref.read(progressionServiceProvider);

    // Parse traits/feats for calculation (using current char data)
    List<String> traits = [];
    List<String> feats = [];
    try {
      traits = (jsonDecode(char.traits) as List).cast<String>();
    } catch (_) {}
    try {
      feats = (jsonDecode(char.feats) as List).cast<String>();
    } catch (_) {}

    final hpPerLevel = service.calculateHpPerLevel(
      constitution: char.constitution, // Use raw CON, boosts applied later?
      // Actually, if we boost CON, does it apply retroactively?
      // In Pathfinder 2e/D&D 5e: YES.
      // But here `calculateHpPerLevel` takes `constitution`.
      // If user boosts CON, we should use NEW CON.
      // For preview, assumes current CON.
      // If user boosts CON, we should show increased HP?
      // Let's keep it simple: Show HP gain based on Current CON. Boosts apply to new level calc in `processLevelUp`.
      traits: traits,
      feats: feats,
      allTraits: allTraits,
      allFeats: allFeats,
    );

    // Calculate total boosts spent
    int spent = attributeBoosts.values.fold(0, (sum, val) => sum + val);

    return AlertDialog(
      title: Text("Level Up to $nextLevel!"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary
              Card(
                color: Colors.deepPurple.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Hit Points Increase:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("+$hpPerLevel",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("New Max HP:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("${char.maxHp + hpPerLevel}",
                              style: const TextStyle(color: Colors.blueAccent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isAttributeBoost) ...[
                const SizedBox(height: 16),
                const Text("Attribute Boosts",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Select 2 attributes to increase (Cap $attributeCap)",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                // Points Counter
                LinearProgressIndicator(
                    value: spent / maxPoints,
                    color: spent == maxPoints ? Colors.green : Colors.amber),
                const SizedBox(height: 8),

                ...attributes.entries.map((entry) {
                  final name = entry.key;
                  final currentVal = entry.value;
                  final boost = attributeBoosts[name] ?? 0;
                  final newVal = currentVal + boost;

                  final canInc = spent < maxPoints && newVal < attributeCap;
                  final canDec = boost > 0;

                  return ListTile(
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$newVal",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: boost > 0 ? Colors.green : null)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: canDec
                              ? () {
                                  setState(() {
                                    if (attributeBoosts[name]! > 0) {
                                      attributeBoosts[name] =
                                          attributeBoosts[name]! - 1;
                                      if (attributeBoosts[name] == 0)
                                        attributeBoosts.remove(name);
                                    }
                                  });
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: canInc
                              ? () {
                                  setState(() {
                                    attributeBoosts[name] =
                                        (attributeBoosts[name] ?? 0) + 1;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                const SizedBox(height: 16),
                const Text("No attribute boosts this level.",
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ]
            ],
          ),
        ),
      ),
      actions: [
        if (isProcessing)
          const CircularProgressIndicator()
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: (isAttributeBoost && spent < maxPoints)
                ? null
                : () async {
                    // Confirm
                    setState(() => isProcessing = true);

                    // Prepare choices
                    String? b1;
                    String? b2;

                    if (isAttributeBoost) {
                      List<String> keys = [];
                      attributeBoosts.forEach((k, v) {
                        for (int i = 0; i < v; i++) keys.add(k);
                      });
                      if (keys.length > 0) b1 = keys[0];
                      if (keys.length > 1) b2 = keys[1];
                    }

                    final choices = LevelUpChoices(
                      attributeBoost1: b1,
                      attributeBoost2: b2,
                    );

                    await service.processLevelUp(
                      characterId: char.id,
                      choices: choices,
                      allTraits: allTraits,
                      allFeats: allFeats,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Level Up to $nextLevel Complete!")),
                      );
                    }
                  },
            child: const Text("Level Up!"),
          )
        ]
      ],
    );
  }
}
