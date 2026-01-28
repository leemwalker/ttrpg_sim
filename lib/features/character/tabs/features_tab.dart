import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/database/database.dart';

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
          subtitle: "Species", // Could fetch desc if we had controller here
          icon: Icons.fingerprint,
          color: Colors.teal,
        ),
        _buildFeatureCard(
          context,
          title: char.origin,
          subtitle: "Origin",
          icon: Icons.history_edu,
          color: Colors.amber[800],
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
      ),
    );
  }
}
