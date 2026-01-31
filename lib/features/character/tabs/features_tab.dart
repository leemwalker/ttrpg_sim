import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

class FeaturesList extends StatelessWidget {
  final CharacterData char;

  const FeaturesList({super.key, required this.char});

  List<String> _parseList(String jsonStr) {
    try {
      if (jsonStr.isEmpty || jsonStr == '[]') return [];
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print("Error parsing list: $e");
    }
    return [];
  }

  void _showFeatureDetails(BuildContext context, String name, String type) {
    final rules = ModularRulesController();
    String description = "No description available.";
    String effect = "";

    if (type == 'Trait') {
      final trait = rules.allTraits
          .cast<dynamic>()
          .firstWhere((t) => t.name == name, orElse: () => null);
      if (trait != null) {
        description = trait.description;
        effect = trait.effect; // Assuming effect field exists
      }
    } else if (type == 'Feat') {
      final feat = rules.allFeats
          .cast<dynamic>()
          .firstWhere((f) => f.name == name, orElse: () => null);
      if (feat != null) {
        description = feat.description;
        effect = feat.effect;
      }
    } else if (type == 'Species') {
      final species = rules.allSpecies
          .cast<dynamic>()
          .firstWhere((s) => s.name == name, orElse: () => null);
      if (species != null) {
        description = species.description ?? "Species description.";
      }
    } else if (type == 'Origin') {
      // Origin isn't exposed as allOrigins yet?
      // If needed, can add getter. For now show basic info.
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            if (effect.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text("Effect:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(effect),
            ]
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final traits = _parseList(char.traits);
    final feats = _parseList(char.feats);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Species
        _buildSectionHeader(context, "Species & Origin"),
        _buildFeatureCard(
          context,
          title: char.species,
          subtitle: "Species",
          icon: Icons.fingerprint,
          color: Colors.teal,
          onTap: () => _showFeatureDetails(context, char.species, 'Species'),
        ),
        _buildFeatureCard(
          context,
          title: char.origin,
          subtitle: "Origin",
          icon: Icons.history_edu,
          color: Colors.amber[800],
          // Origin lookups might need added getter if we want detailed desc
        ),

        const SizedBox(height: 16),

        // Traits
        if (traits.isNotEmpty) ...[
          _buildSectionHeader(context, "Traits (Innate)"),
          ...traits.map((t) => _buildFeatureCard(
                context,
                title: t,
                subtitle: "Biological / Innate",
                icon: Icons.biotech,
                color: Colors.lightGreen,
                onTap: () => _showFeatureDetails(context, t, 'Trait'),
              )),
          const SizedBox(height: 16),
        ],

        // Feats
        if (feats.isNotEmpty) ...[
          _buildSectionHeader(context, "Feats (Learned)"),
          ...feats.map((f) => _buildFeatureCard(
                context,
                title: f,
                subtitle: "Training / Experience",
                icon: Icons.military_tech,
                color: Colors.deepPurpleAccent,
                onTap: () => _showFeatureDetails(context, f, 'Feat'),
              )),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? Colors.grey).withOpacity(0.2),
          child: Icon(icon, color: color ?? Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
