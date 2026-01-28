import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';

class CharacterSelectionScreen extends ConsumerStatefulWidget {
  final int worldId;

  const CharacterSelectionScreen({super.key, required this.worldId});

  @override
  ConsumerState<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState
    extends ConsumerState<CharacterSelectionScreen> {
  // We'll manage local state for the list of characters to avoid
  // needing a new specialized provider just for this screen,
  // or we can just fetch directly in build with FutureBuilder/StreamBuilder.
  // Using a FutureBuilder for simplicity as per existing patterns.

  late Future<List<CharacterData>> _charactersFuture;

  @override
  void initState() {
    super.initState();
    _refreshCharacters();
  }

  void _refreshCharacters() {
    setState(() {
      _charactersFuture =
          ref.read(gameDaoProvider).getCharactersForWorld(widget.worldId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Character'),
      ),
      body: FutureBuilder<List<CharacterData>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final characters = snapshot.data ?? [];

          if (characters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No characters found in this world.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToCreation(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Character'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final character = characters[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(character.name[0]),
                  ),
                  title: Text(character.name),
                  subtitle: Text(
                      'Level ${character.level} ${character.species} - ${character.origin}'),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => GameScreen(
                        worldId: widget.worldId,
                        characterId: character.id,
                      ),
                    ));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () =>
                        _confirmDeleteCharacter(context, character),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreation(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreation(BuildContext context) async {
    // Create a new placeholder character to ensure we are editing a distinct entity
    final dao = ref.read(gameDaoProvider);
    final newCharId = await dao.updateCharacterStats(CharacterCompanion.insert(
      name: "Traveler",
      species: const drift.Value("Human"),
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: "Start",
      worldId: drift.Value(widget.worldId),
    ));

    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (context) => CharacterCreationScreen(
            worldId: widget.worldId, characterId: newCharId),
      ))
          .then((_) {
        // Refresh list when returning from creation
        _refreshCharacters();
      });
    }
  }

  void _confirmDeleteCharacter(BuildContext context, CharacterData character) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete '${character.name}'?"),
          content: const Text(
              "Are you sure you want to delete this character? This will delete their inventory and chat history but NOT the world."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await ref.read(gameDaoProvider).deleteCharacter(character.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshCharacters();
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
