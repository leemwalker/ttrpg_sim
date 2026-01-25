import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
import 'package:ttrpg_sim/features/creation/widgets/point_buy_widget.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';

class CharacterCreationScreen extends ConsumerStatefulWidget {
  final int worldId;

  const CharacterCreationScreen({super.key, required this.worldId});

  @override
  ConsumerState<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState
    extends ConsumerState<CharacterCreationScreen> {
  final _nameController = TextEditingController();
  final _rules = Dnd5eRules();

  String _selectedClass = 'Fighter';
  String _selectedSpecies = 'Human';
  String _selectedBackground = 'Acolyte'; // Default
  int _level = 1;

  // Stats for Point Buy
  Map<String, int> _stats = {
    'Strength': 8,
    'Dexterity': 8,
    'Constitution': 8,
    'Intelligence': 8,
    'Wisdom': 8,
    'Charisma': 8,
  };

  bool _isLoading = true;
  int? _characterId;

  @override
  void initState() {
    super.initState();
    _loadPlaceholderCharacter();
  }

  Future<void> _loadPlaceholderCharacter() async {
    final dao = ref.read(gameDaoProvider);

    // Fetch custom traits first
    final customSpecies = await dao.getCustomTraitsByType('Species');
    final customClasses = await dao.getCustomTraitsByType('Class');

    // Register them with the rules engine
    _rules.registerCustomTraits([...customSpecies, ...customClasses]);

    final character = await dao.getCharacter(widget.worldId);

    if (character != null) {
      setState(() {
        _characterId = character.id;
        _nameController.text =
            character.name == 'Traveler' ? '' : character.name;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_characterId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(
          child: Text("No placeholder character found for this world."),
        ),
      );
    }

    final backgroundInfo = _rules.getBackgroundInfo(_selectedBackground);

    return Scaffold(
      appBar: AppBar(title: const Text("Create Your Character")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Character Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              // CLASS SELECTION
              DropdownButtonFormField<String>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  labelText: "Class",
                  border: OutlineInputBorder(),
                ),
                items: _rules.availableClasses
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedClass = val);
                },
              ),
              const SizedBox(height: 16),
              // SPECIES SELECTION
              DropdownButtonFormField<String>(
                value: _selectedSpecies,
                decoration: const InputDecoration(
                  labelText: "Species",
                  border: OutlineInputBorder(),
                ),
                items: _rules.availableSpecies
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSpecies = val);
                },
              ),
              const SizedBox(height: 16),
              // BACKGROUND SELECTION
              DropdownButtonFormField<String>(
                value: _selectedBackground,
                decoration: const InputDecoration(
                  labelText: "Background",
                  border: OutlineInputBorder(),
                ),
                items: _rules.availableBackgrounds
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBackground = val);
                },
              ),
              const SizedBox(height: 8),
              // BACKGROUND INFO CARD
              Card(
                color: Colors.blueGrey[900],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Feature: ${backgroundInfo.featureName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                      Text(
                        backgroundInfo.featureDesc,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Origin Feat: ${backgroundInfo.originFeat}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.lightGreenAccent),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text("Level: $_level",
                  style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _level.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: _level.toString(),
                onChanged: (val) => setState(() => _level = val.toInt()),
              ),
              const SizedBox(height: 16),

              // POINT BUY WIDGET
              PointBuyWidget(
                onStatsChanged: (stats) {
                  setState(() {
                    _stats = stats;
                  });
                },
              ),

              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Calculated Stats",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Text(
                        "Max HP: ${_rules.calculateMaxHp(_selectedClass, _level)}",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _createCharacter,
                icon: const Icon(Icons.check),
                label: const Text("Create Character"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCharacter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a character name.")),
      );
      return;
    }

    final maxHp = _rules.calculateMaxHp(_selectedClass, _level);
    final dao = ref.read(gameDaoProvider);

    await dao.updateCharacterBio(
      characterId: _characterId!,
      name: name,
      characterClass: _selectedClass,
      species: _selectedSpecies,
      background: _selectedBackground,
      level: _level,
      maxHp: maxHp,
      strength: _stats['Strength']!,
      dexterity: _stats['Dexterity']!,
      constitution: _stats['Constitution']!,
      intelligence: _stats['Intelligence']!,
      wisdom: _stats['Wisdom']!,
      charisma: _stats['Charisma']!,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => GameScreen(worldId: widget.worldId),
      ));
    }
  }
}
