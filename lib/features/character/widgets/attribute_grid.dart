import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/database/database.dart';

class AttributeGrid extends StatelessWidget {
  final CharacterData char;

  const AttributeGrid({super.key, required this.char});

  int _calcMod(int score) => (score - 10) ~/ 2;

  Map<String, int> _parseAttributes() {
    try {
      if (char.attributes.isEmpty || char.attributes == '{}') {
        // Fallback to legacy columns if JSON is empty (Backward Compatibility)
        return {
          'Strength': char.strength,
          'Dexterity': char.dexterity,
          'Constitution': char.constitution,
          'Intelligence': char.intelligence,
          'Wisdom': char.wisdom,
          'Charisma': char.charisma,
        };
      }
      final decoded = jsonDecode(char.attributes);
      if (decoded is Map<String, dynamic>) {
        return Map<String, int>.from(decoded);
      }
    } catch (e) {
      print("Error parsing attributes: $e");
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final attributes = _parseAttributes();

    if (attributes.isEmpty) {
      return const Center(child: Text("No Attributes defined."));
    }

    // Determine sorting order? Usually standard D&D order is nice, but dynamic means arbitrary.
    // We can try to prioritize standard 6, then others.
    final standardOrder = [
      'Strength',
      'Dexterity',
      'Constitution',
      'Intelligence',
      'Wisdom',
      'Charisma'
    ];

    final sortedKeys = attributes.keys.toList();
    sortedKeys.sort((a, b) {
      final indexA = standardOrder.indexOf(a);
      final indexB = standardOrder.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid
        // If width is small, fewer columns.
        // We use Wrap for flow.
        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: sortedKeys.map((key) {
            final score = attributes[key]!;
            final mod = _calcMod(score);
            final modString = mod >= 0 ? "+$mod" : "$mod";

            // Dynamic card width
            final width = (constraints.maxWidth - 32) /
                3; // roughly 3 per row minus spacing

            return Container(
              width: width < 80 ? 80 : width,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 2))
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key.substring(0, 3).toUpperCase(), // Short name (STR, DEX)
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modString,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "$score",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
