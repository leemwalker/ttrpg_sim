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

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeCreation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int? _characterId;

  Future<void> _initializeCreation() async {
    try {
      print('DEBUG: Init Creation Start');
      // 1. Load Rules
      await ModularRulesController().loadRules();

      // 2. Fetch World Genres and Ensure Character
      final dao = ref.read(gameDaoProvider);
      final world = await dao.getWorld(widget.worldId);

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
        ref
            .read(creationProvider.notifier)
            .setMagicEnabled(world.isMagicEnabled);
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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR in _initializeCreation: $e');
    }
  }

  void _nextPage() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finishCreation();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final steps = [
      const StepSpecies(),
      const StepOrigin(),
      const StepTraits(),
      const StepAttributes(),
      const StepSkillsMagic(),
    ];

    final titles = [
      "Select Species",
      "Select Origin",
      "Choose Traits",
      "Assign Attributes",
      "Skills & Magic"
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevPage,
        ),
      ),
      body: Column(
        children: [
          // Step Indicator (LinearProgressIndicator or Dots)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: List.generate(5, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    color: index <= _currentStep
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
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
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: steps
                  .map((step) => SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: step,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  key: const ValueKey('nav_back_button'),
                  onPressed: _prevPage,
                  child: const Text("Back"),
                )
              else
                const SizedBox.shrink(),
              FilledButton(
                key: const ValueKey('nav_next_button'),
                onPressed: _nextPage,
                child: Text(_currentStep == 4 ? "Finish" : "Next"),
              ),
            ],
          ),
        ),
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
    // Use totalAttributes to include species bonuses
    final finalAttributes = ref.read(creationProvider.notifier).totalAttributes;
    final attributesJson = jsonEncode(finalAttributes);
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
    final int con = finalAttributes['Constitution'] ?? 10;
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
      strength: finalAttributes['Strength'] ?? 10,
      dexterity: finalAttributes['Dexterity'] ?? 10,
      constitution: finalAttributes['Constitution'] ?? 10,
      intelligence: finalAttributes['Intelligence'] ?? 10,
      wisdom: finalAttributes['Wisdom'] ?? 10,
      charisma: finalAttributes['Charisma'] ?? 10,
    );

    if (mounted) {
      Navigator.of(context).pop();
      // Or navigate to Game
    }
  }
}
