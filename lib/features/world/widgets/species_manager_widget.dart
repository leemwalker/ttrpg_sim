import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

class SpeciesManagerWidget extends StatefulWidget {
  final List<String> selectedGenres;
  final ValueChanged<String> onConfigChanged;

  const SpeciesManagerWidget({
    super.key,
    required this.selectedGenres,
    required this.onConfigChanged,
  });

  @override
  State<SpeciesManagerWidget> createState() => _SpeciesManagerWidgetState();
}

class _SpeciesManagerWidgetState extends State<SpeciesManagerWidget> {
  final Set<String> _excludedSpecies = {};
  final Set<String> _includedExoticSpecies = {};
  final List<Map<String, dynamic>> _customSpecies = [];

  // Categorized species from rules
  List<SpeciesDef> _coreSpecies = [];
  List<SpeciesDef> _exoticSpecies = [];

  @override
  void initState() {
    super.initState();
    _categorizeSpecies();
  }

  @override
  void didUpdateWidget(covariant SpeciesManagerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGenres != widget.selectedGenres) {
      _categorizeSpecies();
      // Optional: Clear selections or keep them?
      // Keeping them might be confusing if a species moves from Exotic to Core.
      // For safety/simplicity, we re-validate or just let them be.
      // If a species becomes Core, remove from includedExotic.
      // If a species becomes Exotic, remove from excluded.
      setState(() {
        _excludedSpecies
            .removeWhere((s) => _exoticSpecies.any((e) => e.name == s));
        _includedExoticSpecies
            .removeWhere((s) => _coreSpecies.any((c) => c.name == s));
      });
      _emitConfig();
    }
  }

  void _categorizeSpecies() {
    final all = ModularRulesController().allSpecies;
    _coreSpecies = [];
    _exoticSpecies = [];

    // Primitive matching based on Controller logic
    // We duplicate the logic slightly to split them
    for (var s in all) {
      bool isCore = s.genre == 'Universal';
      if (!isCore) {
        for (var g in widget.selectedGenres) {
          if (s.genre.contains(g)) {
            isCore = true;
            break;
          }
        }
      }

      if (isCore) {
        _coreSpecies.add(s);
      } else {
        _exoticSpecies.add(s);
      }
    }
  }

  void _emitConfig() {
    final config = {
      "excluded": _excludedSpecies.toList(),
      "included": _includedExoticSpecies.toList(),
      "custom": _customSpecies,
    };
    widget.onConfigChanged(jsonEncode(config));
  }

  void _addCustomSpecies() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CustomSpeciesDialog(),
    );

    if (result != null) {
      setState(() {
        _customSpecies.add(result);
      });
      _emitConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Species Configuration",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "Manage which species inhabit this world.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        // Custom Species Section
        if (_customSpecies.isNotEmpty) ...[
          Text("Custom Species", style: Theme.of(context).textTheme.titleSmall),
          ..._customSpecies.map((s) => ListTile(
                title: Text(s['name'] ?? 'Unnamed'),
                subtitle: Text("${s['stats']} | ${s['traits']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _customSpecies.remove(s);
                    });
                    _emitConfig();
                  },
                ),
                dense: true,
              )),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _addCustomSpecies,
          icon: const Icon(Icons.add),
          label: const Text("Create Custom Species"),
        ),
        const SizedBox(height: 16),

        // Core Species (Auto-included)
        ExpansionTile(
          title: Text("Core Species (${_coreSpecies.length})"),
          subtitle: const Text("Automatically included by genre"),
          initiallyExpanded: true,
          children: _coreSpecies.map((s) {
            final isExcluded = _excludedSpecies.contains(s.name);
            return SwitchListTile(
              title: Text(s.name),
              subtitle: Text(s.stats.entries
                  .map((e) => "${e.key} ${e.value > 0 ? '+' : ''}${e.value}")
                  .join(', ')),
              value: !isExcluded,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _excludedSpecies.remove(s.name);
                  } else {
                    _excludedSpecies.add(s.name);
                  }
                });
                _emitConfig();
              },
            );
          }).toList(),
        ),

        // Exotic Species (Auto-excluded)
        ExpansionTile(
          title: Text("Exotic Species (${_exoticSpecies.length})"),
          subtitle: const Text("From other genres"),
          children: _exoticSpecies.map((s) {
            final isIncluded = _includedExoticSpecies.contains(s.name);
            return SwitchListTile(
              title: Text(s.name),
              subtitle: Text("${s.genre} - ${s.stats.keys.join(', ')}"),
              value: isIncluded,
              activeColor: Theme.of(context).colorScheme.secondary,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _includedExoticSpecies.add(s.name);
                  } else {
                    _includedExoticSpecies.remove(s.name);
                  }
                });
                _emitConfig();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CustomSpeciesDialog extends StatefulWidget {
  const _CustomSpeciesDialog();

  @override
  State<_CustomSpeciesDialog> createState() => _CustomSpeciesDialogState();
}

class _CustomSpeciesDialogState extends State<_CustomSpeciesDialog> {
  final _nameCtrl = TextEditingController();
  final _statsCtrl = TextEditingController(text: "+2 STR");
  final _traitsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  void _save() {
    if (_nameCtrl.text.isEmpty) return;

    final traits = _traitsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Navigator.of(context).pop({
      "name": _nameCtrl.text,
      "stats": _statsCtrl.text,
      "traits": traits,
      "description": _descCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("New Custom Species"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Species Name"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _statsCtrl,
              decoration: const InputDecoration(
                labelText: "Stat Bonus",
                hintText: "e.g., +2 STR, +1 DEX",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _traitsCtrl,
              decoration: const InputDecoration(
                labelText: "Traits (comma separated)",
                hintText: "Night Vision, Magic",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text("Add"),
        ),
      ],
    );
  }
}
