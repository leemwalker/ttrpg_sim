import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/campaign/character_selection_screen.dart';
import 'package:ttrpg_sim/features/settings/settings_screen.dart';
import 'package:ttrpg_sim/features/world/create_world_screen.dart';

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
                  // Display primary genre + tone or description
                  subtitle: Text("${world.genre} (${world.tone})"),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          CharacterSelectionScreen(worldId: world.id),
                    ));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteWorld(context, world),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const CreateWorldScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDeleteWorld(BuildContext context, World world) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete '${world.name}'?"),
          content: const Text(
              "Are you sure you want to delete this world? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                ref.read(gameDaoProvider).deleteWorld(world.id);
                ref.invalidate(worldsProvider);
                Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
