import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
// import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

class SkillList extends StatelessWidget {
  final CharacterData char;

  const SkillList({super.key, required this.char});

  Map<String, int> _parseSkills() {
    try {
      if (char.skills.isEmpty || char.skills == '{}') {
        return {};
      }
      final decoded = jsonDecode(char.skills);
      if (decoded is Map<String, dynamic>) {
        return Map<String, int>.from(decoded);
      }
    } catch (e) {
      print("Error parsing skills: $e");
    }
    return {};
  }

  // Helper to calculate mod from attribute score
  int _getMod(int score) => (score - 10) ~/ 2;

  // We need attributes to calculate total bonus.
  Map<String, int> _parseAttributes() {
    try {
      if (char.attributes.isEmpty || char.attributes == '{}') return {};
      final decoded = jsonDecode(char.attributes);
      if (decoded is Map<String, dynamic>) {
        return Map<String, int>.from(decoded);
      }
    } catch (e) {
      return {};
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final skillsMap = _parseSkills();
    final attributesMap = _parseAttributes();

    // We need to fetch SkillDefs to look up the attribute for each skill.
    // However, ModularRulesController.loadRules() needs to have been called.
    // Assuming it is loaded in App init or Character Screen init.
    // We can't await here in build. We assume data is available or fallback.

    if (skillsMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No skills known."),
      );
    }

    // Convert to list for display
    final skillEntries = skillsMap.entries.toList();
    skillEntries.sort((a, b) => a.key.compareTo(b.key));

    // Access rules synchronously if loaded?
    // `getSkills` requires genres. We don't have world genres easily here from just `CharacterData`.
    // But we might access `allSkills` if we added the helper to Controller.
    final allSkills = ModularRulesController().allSkills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text("Skills",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: skillEntries.length,
          itemBuilder: (context, index) {
            final entry = skillEntries[index];
            final name = entry.key;
            final rank = entry.value;

            // Look up definition
            final def = allSkills
                .cast<dynamic>()
                .firstWhere((s) => s.name == name, orElse: () => null);
            final attributeName = def != null ? def.attribute : '???';

            // Calculate Bonus: Rank + Attribute Mod
            // Rank usually adds Proficiency Bonus (PB)?
            // In this modular system: "Rank 0-2".
            // Let's assume Rank 1 = +2 (Proficient), Rank 2 = +4 (Expert)? Or just +Rank?
            // User prompt says "Rank 0-2".
            // Let's assume standard d20 simplification: Rank is the bonus? Or Rank is the PB multiplier?
            // "Rank 1" usually implies Proficiency.
            // Let's just display Rank for now, or Rank + Mod.

            int attrScore = attributesMap[attributeName] ?? 10;
            // Legacy fallback if map empty but columns exist?
            if (attributesMap.isEmpty) {
              switch (attributeName) {
                case 'Strength':
                  attrScore = char.strength;
                  break;
                case 'Dexterity':
                  attrScore = char.dexterity;
                  break;
                case 'Constitution':
                  attrScore = char.constitution;
                  break;
                case 'Intelligence':
                  attrScore = char.intelligence;
                  break;
                case 'Wisdom':
                  attrScore = char.wisdom;
                  break;
                case 'Charisma':
                  attrScore = char.charisma;
                  break;
              }
            }

            final int mod = _getMod(attrScore);

            // Per requirement: "Skill Rank + Attribute Modifier"
            // We interpret "Rank" as the direct bonus value (0, 1, 2).
            final int skillBonus = rank + mod;

            final bonusSign = skillBonus >= 0 ? "+" : "";

            return ListTile(
              dense: true,
              title: Text(name),
              subtitle: Text("$attributeName ($rank)"),
              trailing: Text("$bonusSign$skillBonus",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            );
          },
        ),
      ],
    );
  }
}
