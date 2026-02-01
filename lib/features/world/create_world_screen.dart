import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

class CreateWorldScreen extends ConsumerStatefulWidget {
  const CreateWorldScreen({super.key});

  @override
  ConsumerState<CreateWorldScreen> createState() => _CreateWorldScreenState();
}

class _CreateWorldScreenState extends ConsumerState<CreateWorldScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _toneController = TextEditingController();

  List<String> _availableGenres = [];
  bool _isLoading = true;
  bool _isMagicEnabled = false;
  GameDifficulty _selectedDifficulty = GameDifficulty.medium;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    // Ensure rules are loaded (if not already)
    // In a real app, rules might be loaded at bootstrap, but safe to call here.
    await ModularRulesController().loadRules();
    final genres = ModularRulesController().getAllGenres();

    if (mounted) {
      setState(() {
        _availableGenres = genres.map((g) => g.name).toList();
        // Fallback if empty (e.g. no CSV found)
        if (_availableGenres.isEmpty) {
          _availableGenres = ['Fantasy', 'Sci-Fi', 'Custom'];
        }
        _isLoading = false;
      });
    }
  }

  final Set<String> _selectedGenres = {};

  void _toggleGenre(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
      // Auto-set magic toggle based on selected genres
      _isMagicEnabled = _selectedGenres
          .any((g) => ['Fantasy', 'Horror', 'Superhero'].contains(g));
    });
  }

  Future<void> _createWorld() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a world name.")),
      );
      return;
    }

    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one genre.")),
      );
      return;
    }

    final dao = ref.read(gameDaoProvider);
    final genresJson = jsonEncode(_selectedGenres.toList());
    // Primary genre for legacy/display column if needed
    final mainGenre = _selectedGenres.first;

    // Create World
    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: name,
      genre: mainGenre, // Keeping main genre for quick display
      genres: drift.Value(genresJson),
      tone: drift.Value(
          _toneController.text.isEmpty ? 'Standard' : _toneController.text),
      description: _descriptionController.text,
      isMagicEnabled: drift.Value(_isMagicEnabled),
      difficulty: drift.Value(
          _selectedDifficulty.toString().split('.').last.capitalize()),
    ));

    // Create Initial Linked Character (Traveler/Placeholder)
    await dao.updateCharacterStats(CharacterCompanion.insert(
      name: "Traveler",
      // heroClass: Value('Unknown') // Removed in db v15
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: "Start",
      worldId: drift.Value(worldId),
      species: const drift.Value("Human"),
      origin: const drift.Value("Unknown"),
      attributes: const drift.Value("{}"),
      skills: const drift.Value("{}"),
      traits: const drift.Value("[]"),
      feats: const drift.Value("[]"),
    ));

    // Invalidate worlds list to refresh menu
    ref.invalidate(worldsProvider);

    if (mounted) {
      // Navigate to Character Creation
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => CharacterCreationScreen(worldId: worldId),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Create New World")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "World Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 16),
            Text("Genres", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _availableGenres.map((genre) {
                final isSelected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (_) => _toggleGenre(genre),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _toneController,
              decoration: const InputDecoration(
                labelText: "Tone",
                hintText: "e.g., Gritty, Whimsical, Dark",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.mood),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GameDifficulty>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: "Difficulty",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.signal_cellular_alt),
              ),
              items: GameDifficulty.values.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(d.toString().split('.').last.capitalize()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedDifficulty = val);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _getDifficultyDescription(_selectedDifficulty),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Magic/Powers'),
              subtitle: const Text('Allow characters to use magical abilities'),
              value: _isMagicEnabled,
              onChanged: (val) => setState(() => _isMagicEnabled = val),
              secondary: Icon(
                Icons.auto_fix_high,
                color: _isMagicEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createWorld,
              icon: const Icon(Icons.add_location_alt),
              label: const Text("Create World"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDifficultyDescription(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return "Heroic start. High stats, extra skills.";
      case GameDifficulty.medium:
        return "Standard adventure balance.";
      case GameDifficulty.hard:
        return "Gritty. Resources are scarce.";
      case GameDifficulty.expert:
        return "Survival is unlikely. Minimal resources.";
      case GameDifficulty.custom:
        return "Sandbox. No limits. Max stats 30.";
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
