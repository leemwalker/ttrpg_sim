import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
// import 'package:ttrpg_sim/core/database/database.dart'; // For CharacterData type if needed
import 'package:ttrpg_sim/features/character/widgets/attribute_grid.dart';
import 'package:ttrpg_sim/features/character/widgets/skill_list.dart';
import 'package:ttrpg_sim/features/character/tabs/features_tab.dart';
import 'package:ttrpg_sim/features/character/tabs/grimoire_tab.dart';

class CharacterDrawer extends ConsumerWidget {
  final int worldId;
  const CharacterDrawer({super.key, required this.worldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch character data
    final characterAsync = ref.watch(characterDataProvider(worldId));

    return Drawer(
      child: characterAsync.when(
        data: (char) {
          if (char == null) {
            return ListView(
                children: const [ListTile(title: Text("No Character Data"))]);
          }

          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.deepPurple),
                  accountName: Text(char.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  accountEmail: Text(
                      "Level ${char.level} | ${char.species} | ${char.origin}"),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      char.name.isNotEmpty ? char.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple),
                    ),
                  ),
                ),
                const TabBar(
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.bar_chart), text: "Stats"),
                    Tab(icon: Icon(Icons.auto_fix_high), text: "Magic"),
                    Tab(icon: Icon(Icons.star), text: "Feats"),
                    Tab(icon: Icon(Icons.backpack), text: "Inv"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Stats Tab
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("HP: ${char.currentHp}/${char.maxHp}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text("Gold: ${char.gold}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber)),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: AttributeGrid(char: char),
                            ),
                            const Divider(),
                            SkillList(char: char),
                          ],
                        ),
                      ),

                      // Grimoire Tab
                      GrimoireTab(character: char),

                      // Features Tab
                      FeaturesList(char: char),

                      // Inventory Tab
                      InventorySection(charId: char.id),
                    ],
                  ),
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}

class InventorySection extends ConsumerWidget {
  final int charId;
  const InventorySection({super.key, required this.charId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryDataProvider(charId));

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child:
              Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: inventoryAsync.when(
            data: (items) {
              if (items.isEmpty) return const Center(child: Text("Empty"));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final i = items[index];
                  return ListTile(
                    leading: const Icon(Icons.business_center),
                    title: Text(i.itemName),
                    trailing: Text("x${i.quantity}"),
                    onTap: () {
                      // Potential inspect/use item logic
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        )
      ],
    );
  }
}
