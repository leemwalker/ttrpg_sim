import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ttrpg_sim/features/settings/settings_screen.dart';

class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  @override
  Widget build(BuildContext context) {
    final worldsAsync = ref.watch(worldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select World"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ));
            },
          ),
        ],
      ),
      body: worldsAsync.when(
        data: (worlds) {
          if (worlds.isEmpty) {
            return const Center(child: Text("No worlds found. Create one!"));
          }
          return ListView.builder(
            itemCount: worlds.length,
            itemBuilder: (context, index) {
              final world = worlds[index];
              return Card(
                child: ListTile(
                  title: Text(world.name),
                  subtitle: Text("${world.genre} - ${world.description}"),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => GameScreen(worldId: world.id),
                    ));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateWorldDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateWorldDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final customGenreController = TextEditingController();
    String selectedGenre = "Fantasy";
    final genres = ["Fantasy", "Sci-Fi", "Horror", "Cyberpunk", "Custom"];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Create New World"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "World Name"),
                  ),
                  const SizedBox(height: 16),
                  const Text("Genre:"),
                  Wrap(
                    spacing: 8.0,
                    children: genres.map((genre) {
                      return ChoiceChip(
                        label: Text(genre),
                        selected: selectedGenre == genre,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => selectedGenre = genre);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedGenre == "Custom")
                    TextField(
                      controller: customGenreController,
                      decoration: const InputDecoration(
                          labelText: "Enter Custom Genre"),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: "Concept/Description"),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text;
                  final description = descriptionController.text;

                  // Determine final genre string
                  final finalGenre = selectedGenre == "Custom"
                      ? customGenreController.text
                      : selectedGenre;

                  if (name.isNotEmpty && finalGenre.isNotEmpty) {
                    final dao = ref.read(gameDaoProvider);
                    // Create World
                    final worldId =
                        await dao.createWorld(WorldsCompanion.insert(
                      name: name,
                      genre: finalGenre,
                      description: description,
                    ));

                    // Create Initial Linked Character (Placeholder)
                    await dao.updateCharacterStats(CharacterCompanion.insert(
                      name: "Traveler",
                      heroClass: "Unknown",
                      species: const drift.Value("Human"),
                      level: 1,
                      currentHp: 10,
                      maxHp: 10,
                      gold: 0,
                      location: "Start",
                      worldId: drift.Value(worldId),
                    ));

                    if (context.mounted) {
                      Navigator.pop(context); // Close Dialog
                      // Refresh List
                      ref.invalidate(worldsProvider);
                      // Navigate to Character Creation
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            CharacterCreationScreen(worldId: worldId),
                      ));
                    }
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        });
      },
    );
  }
}
