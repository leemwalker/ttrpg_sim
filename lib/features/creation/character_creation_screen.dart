import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
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
  int _level = 1;

  bool _isLoading = true;
  int? _characterId;

  @override
  void initState() {
    super.initState();
    _loadPlaceholderCharacter();
  }

  Future<void> _loadPlaceholderCharacter() async {
    final dao = ref.read(gameDaoProvider);
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
      level: _level,
      maxHp: maxHp,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => GameScreen(worldId: widget.worldId),
      ));
    }
  }
}
