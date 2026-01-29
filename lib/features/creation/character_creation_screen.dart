import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/features/creation/steps/step_attributes.dart';
import 'package:ttrpg_sim/features/creation/steps/step_origin.dart';
import 'package:ttrpg_sim/features/creation/steps/step_skills_magic.dart';
import 'package:ttrpg_sim/features/creation/steps/step_species.dart';
import 'package:ttrpg_sim/features/creation/steps/step_traits.dart';

class CharacterCreationScreen extends ConsumerStatefulWidget {
  final int worldId;
  final int? characterId;

  const CharacterCreationScreen(
      {super.key, required this.worldId, this.characterId});

  @override
  ConsumerState<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState
    extends ConsumerState<CharacterCreationScreen> {
  int _currentStep = 0;
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCreation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int? _characterId;

  Future<void> _initializeCreation() async {
    try {
      print('DEBUG: Init Creation Start');
      // 1. Load Rules
      await ModularRulesController().loadRules();
      print('DEBUG: Rules Loaded');

      // 2. Fetch World Genres and Ensure Character
      final dao = ref.read(gameDaoProvider);
      final world = await dao.getWorld(widget.worldId);
      print('DEBUG: World fetched: ${world?.name}');

      if (world != null) {
        List<String> genres = [];
        try {
          final parsed = jsonDecode(world.genres);
          if (parsed is List) {
            genres = parsed.map((e) => e.toString()).toList();
          }
        } catch (e) {
          genres = ['Fantasy'];
        }
        ref.read(creationProvider.notifier).setGenres(genres);
      }

      // Ensure Character exists (Placeholder logic)
      if (widget.characterId != null) {
        _characterId = widget.characterId;
      } else {
        final existing = await dao.getCharacter(widget.worldId);
        if (existing != null) {
          _characterId = existing.id;
          if (existing.name != 'Traveler' && existing.name.isNotEmpty) {
            _nameController.text = existing.name;
          }
        } else {
          _characterId = await dao.updateCharacterStats(
              CharacterCompanion.insert(
                      name: 'Traveler',
                      level: 1,
                      currentHp: 10,
                      maxHp: 10,
                      gold: 0,
                      location: 'Unknown',
                      species: const Value('Human'),
                      origin: const Value('Unknown'))
                  .copyWith(worldId: Value(widget.worldId)));
        }
      }
      print('DEBUG: Character ID: $_characterId');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('DEBUG: Set Loading False');
      }
    } catch (e, st) {
      print('ERROR in _initializeCreation: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check validation for current step to enable Next button?
    // Simplified: Allow navigation, validate on Finish or visual cues.

    return Scaffold(
      appBar: AppBar(
        title: const Text("Character Creation"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Character Name",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 4) {
                  setState(() => _currentStep += 1);
                } else {
                  _finishCreation();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                } else {
                  Navigator.of(context).pop();
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      FilledButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 4 ? "Finish" : "Next"),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text("Back"),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text("Species"),
                  content: const StepSpecies(),
                  isActive: _currentStep >= 0,
                  state:
                      _currentStep > 0 ? StepState.complete : StepState.editing,
                ),
                Step(
                  title: const Text("Origin"),
                  content: const StepOrigin(),
                  isActive: _currentStep >= 1,
                  state:
                      _currentStep > 1 ? StepState.complete : StepState.editing,
                ),
                Step(
                  title: const Text("Traits"),
                  content: const StepTraits(),
                  isActive: _currentStep >= 2,
                  state:
                      _currentStep > 2 ? StepState.complete : StepState.editing,
                ),
                Step(
                  title: const Text("Attributes"),
                  content: const StepAttributes(),
                  isActive: _currentStep >= 3,
                  state:
                      _currentStep > 3 ? StepState.complete : StepState.editing,
                ),
                Step(
                  title: const Text("Skills/Magic"),
                  content: const StepSkillsMagic(),
                  isActive: _currentStep >= 4,
                  state: _currentStep == 4
                      ? StepState.editing
                      : StepState.complete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishCreation() async {
    final state = ref.read(creationProvider);
    final dao = ref.read(gameDaoProvider);

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter a name.")));
      return;
    }

    if (state.selectedSpecies == null || state.selectedOrigin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Species and Origin.")));
      return;
    }

    // Map to DB
    final attributesJson = jsonEncode(state.attributes);
    final skillsJson = jsonEncode(state.skillRanks);
    final traitsJson =
        jsonEncode(state.selectedTraits.map((t) => t.name).toList());
    final featsJson =
        jsonEncode(state.selectedFeats.map((f) => f.name).toList());

    // Magic into Backstory
    String backstory = "Origin: ${state.selectedOrigin!.name}\n";
    if (state.magicPillar != null) {
      backstory += "\nMagic Pillar: ${state.magicPillar}";
      if (state.magicDescription != null) {
        backstory += "\n${state.magicDescription}";
      }
    }

    // Calculate Max HP (Roughly)
    // 10 + Con Mod
    final int con = state.attributes['Constitution'] ?? 10;
    final int conMod = ((con - 10) / 2).floor();
    final int maxHp = 10 + conMod;

    await dao.updateCharacterBio(
      characterId: _characterId!,
      name: _nameController.text,
      species: state.selectedSpecies!.name,
      origin: state.selectedOrigin!.name,
      attributes: attributesJson,
      skills: skillsJson,
      traits: traitsJson,
      feats: featsJson,
      background: state.selectedOrigin!.name,
      backstory: backstory,
      level: 1,
      maxHp: maxHp,
      // Legacy Columns compat
      strength: state.attributes['Strength'] ?? 10,
      dexterity: state.attributes['Dexterity'] ?? 10,
      constitution: state.attributes['Constitution'] ?? 10,
      intelligence: state.attributes['Intelligence'] ?? 10,
      wisdom: state.attributes['Wisdom'] ?? 10,
      charisma: state.attributes['Charisma'] ?? 10,
    );

    if (mounted) {
      Navigator.of(context).pop();
      // Or navigate to Game
    }
  }
}
