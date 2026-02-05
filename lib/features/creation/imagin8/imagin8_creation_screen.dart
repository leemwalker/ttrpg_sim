import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';

// Provider to fetch available decks - moved to a proper provider file in real app, but ok here for now
final availableDecksProvider = FutureProvider<List<String>>((ref) async {
  final dao = ref.watch(gameDaoProvider);
  return dao.getAvailableDecks();
});

// Provider to fetch cards for selected decks
final imagin8CardsProvider =
    FutureProvider.family<List<Imagin8Card>, List<String>>((ref, decks) async {
  final dao = ref.watch(gameDaoProvider);
  return dao.getCardsForDecks(decks);
});

class Imagin8CreationScreen extends ConsumerStatefulWidget {
  final int worldId;
  const Imagin8CreationScreen({super.key, required this.worldId});

  @override
  ConsumerState<Imagin8CreationScreen> createState() =>
      _Imagin8CreationScreenState();
}

class _Imagin8CreationScreenState extends ConsumerState<Imagin8CreationScreen> {
  int _currentStep = 0;
  List<String> _worldDecks = [];
  bool _isLoading = true;

  // Character Data
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController(); // Bio/Description
  List<Imagin8Card> _selectedCards = [];

  @override
  void initState() {
    super.initState();
    _loadWorldDecks();
  }

  Future<void> _loadWorldDecks() async {
    final dao = ref.read(gameDaoProvider);
    final world = await dao.getWorld(widget.worldId);
    if (world != null && world.selectedDecks != null) {
      if (mounted) {
        setState(() {
          _worldDecks = List<String>.from(jsonDecode(world.selectedDecks!));
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleCard(Imagin8Card card) {
    setState(() {
      if (_selectedCards.any((c) => c.id == card.id)) {
        _selectedCards.removeWhere((c) => c.id == card.id);
      } else {
        final normalCardCount =
            _selectedCards.where((c) => c.type != 'Drawback').length;

        if (card.type == 'Drawback') {
          // Drawbacks don't count towards the 8-card hand limit
          _selectedCards.add(card);
        } else {
          if (normalCardCount < 8) {
            _selectedCards.add(card);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Max 8 normal cards allowed.")));
          }
        }
      }
    });
  }

  Future<void> _saveCharacter() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a character name.")));
      return;
    }

    final dao = ref.read(gameDaoProvider);
    final handIds = _selectedCards.map((c) => c.id).toList();

    // Create Character with minimal Imagin8 defaults
    await dao.updateCharacterStats(CharacterCompanion.insert(
      name: _nameController.text,
      worldId: drift.Value(widget.worldId),
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: "Start",
      species: const drift.Value("Imagin8"),
      origin: const drift.Value("Custom"),
      backstory: drift.Value(_descriptionController.text),
      hand: drift.Value(jsonEncode(handIds)),
      attributes: const drift.Value("{}"),
      skills: const drift.Value("{}"),
      traits: const drift.Value("[]"),
      feats: const drift.Value("[]"),
    ));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool get _isValid {
    final abilityCount =
        _selectedCards.where((c) => c.type == 'Ability').length;
    final drawbackCount =
        _selectedCards.where((c) => c.type == 'Drawback').length;
    final normalCardCount =
        _selectedCards.where((c) => c.type != 'Drawback').length;

    final maxDrawbacks = abilityCount > 2 ? abilityCount : 2;

    final isBalanced = abilityCount <= drawbackCount;
    final isWithinLimit = drawbackCount <= maxDrawbacks;
    final hasEnoughCards = normalCardCount == 8;

    return hasEnoughCards && isBalanced && isWithinLimit;
  }

  String? get _validationError {
    final normalCardCount =
        _selectedCards.where((c) => c.type != 'Drawback').length;

    if (normalCardCount != 8)
      return "Must select exactly 8 normal cards (${normalCardCount}/8)";

    final abilityCount =
        _selectedCards.where((c) => c.type == 'Ability').length;
    final drawbackCount =
        _selectedCards.where((c) => c.type == 'Drawback').length;

    if (abilityCount > drawbackCount)
      return "Unbalanced! Need ${abilityCount - drawbackCount} more Drawback(s)";

    final maxDrawbacks = abilityCount > 2 ? abilityCount : 2;
    if (drawbackCount > maxDrawbacks)
      return "Too many Drawbacks! Max $maxDrawbacks allowed (based on Abilities)";

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cardsAsync = ref.watch(imagin8CardsProvider(_worldDecks));

    return Scaffold(
      appBar: AppBar(title: const Text("Create Imagin8 Character")),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) setState(() => _currentStep++);
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentStep == 2 && !_isValid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_validationError ?? "",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                Row(
                  children: [
                    if (_currentStep < 2)
                      FilledButton(
                        onPressed: details.onStepContinue,
                        child: const Text('Next'),
                      ),
                    if (_currentStep == 2)
                      FilledButton.icon(
                        onPressed: _isValid ? _saveCharacter : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Create Character'),
                      ),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text("Origins"),
            content: _buildOriginStep(cardsAsync),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text("Build Hand"),
            content: _buildHandStep(cardsAsync),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text("Finalize"),
            content: _buildFinalizeStep(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOriginStep(AsyncValue<List<Imagin8Card>> cardsAsync) {
    return cardsAsync.when(
      data: (cards) {
        final origins = cards.where((c) => c.type == 'Origin').toList();
        return SizedBox(
          height: 400,
          child: ListView.builder(
            itemCount: origins.length,
            itemBuilder: (context, index) {
              final origin = origins[index];
              return Card(
                child: ListTile(
                  title: Text(origin.name),
                  subtitle: Text(origin.description),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Auto-select components logic could go here
                    // For now, just a stub or maybe we skip auto-selection to let user build freely
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Selected ${origin.name} template")));
                    // TODO: Parse origin.mechanic to get list of component names and auto-select them
                    setState(() => _currentStep++);
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text("Error: $e"),
    );
  }

  Widget _buildHandStep(AsyncValue<List<Imagin8Card>> cardsAsync) {
    return cardsAsync.when(
      data: (cards) {
        // Filter out Origins for the hand building part
        final handCards = cards.where((c) => c.type != 'Origin').toList();
        return Column(
          children: [
            Text("Selected Cards: ${_selectedCards.length} / 8"),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _selectedCards
                  .map((c) => Chip(
                        label: Text(c.name),
                        onDeleted: () => _toggleCard(c),
                      ))
                  .toList(),
            ),
            const Divider(),
            SizedBox(
              height: 300,
              child: GridView.builder(
                key: const Key('handGrid'),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                ),
                itemCount: handCards.length,
                itemBuilder: (context, index) {
                  final card = handCards[index];
                  final isSelected = _selectedCards.any((c) => c.id == card.id);
                  return InkWell(
                    onTap: () => _toggleCard(card),
                    child: Card(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(card.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            Text(card.type,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
          child:
              CircularProgressIndicator()), // Assuming generic loading widget or use CircularProgressIndicator
      error: (e, s) => Text("Error loading cards: $e"),
    );
  }

  Widget _buildFinalizeStep() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: "Character Name"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: "Description / Bio"),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        const Text("Hand Summary:"),
        ..._selectedCards.map((c) => Text("- ${c.name} (${c.type})")),
      ],
    );
  }
}
