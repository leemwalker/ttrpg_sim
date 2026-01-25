import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/database/database.dart'; // For CharacterData type if needed

class CharacterDrawer extends ConsumerWidget {
  final int worldId;
  const CharacterDrawer({super.key, required this.worldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch character data
    final characterAsync = ref.watch(characterDataProvider(worldId));

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              "Character Sheet",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          characterAsync.when(
            data: (char) {
              if (char == null) {
                return const ListTile(title: Text("No Character Data"));
              }

              return Column(
                children: [
                  // Name & Class
                  ListTile(
                    title: Text(char.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${char.heroClass} Level ${char.level}"),
                  ),

                  // Location Section (New)
                  LocationDisplay(locationId: char.currentLocationId),

                  const Divider(),

                  // HP
                  ListTile(
                    title: Text("HP: ${char.currentHp}/${char.maxHp}"),
                    subtitle: LinearProgressIndicator(
                      value:
                          char.maxHp > 0 ? (char.currentHp / char.maxHp) : 0.0,
                      backgroundColor: Colors.grey[300],
                      color: Colors.red,
                    ),
                  ),

                  // Attributes Section (New)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: AttributesGrid(char: char),
                  ),

                  const Divider(),

                  // Gold
                  ListTile(
                    leading:
                        const Icon(Icons.monetization_on, color: Colors.amber),
                    title: Text("Gold: ${char.gold}"),
                  ),

                  const Divider(),

                  // Inventory
                  InventorySection(charId: char.id),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => ListTile(title: Text('Error: $err')),
          ),
        ],
      ),
    );
  }
}

class LocationDisplay extends ConsumerWidget {
  final int? locationId;
  const LocationDisplay({super.key, required this.locationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch location data
    final locationAsync = ref.watch(locationDataProvider(locationId));

    return locationAsync.when(
      data: (loc) {
        final name = loc?.name ?? 'Unknown / Traveling';
        final type = loc?.type ?? '';
        return ListTile(
          leading: const Icon(Icons.map, color: Colors.blue),
          title: Text("Location: $name"),
          subtitle: type.isNotEmpty ? Text(type) : null,
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.map, color: Colors.grey),
        title: Text("Loading location..."),
      ),
      error: (e, s) => ListTile(title: Text("Loc Error: $e")),
    );
  }
}

class AttributesGrid extends StatelessWidget {
  final CharacterData char;
  const AttributesGrid({super.key, required this.char});

  int _calcMod(int score) => (score - 10) ~/ 2;

  Widget _buildStat(String label, int score) {
    final mod = _calcMod(score);
    final modString = mod >= 0 ? "+$mod" : "$mod";

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(modString,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("($score)",
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          _buildStat("STR", char.strength),
          _buildStat("DEX", char.dexterity),
          _buildStat("CON", char.constitution),
          _buildStat("INT", char.intelligence),
          _buildStat("WIS", char.wisdom),
          _buildStat("CHA", char.charisma),
        ],
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
        inventoryAsync.when(
          data: (items) {
            if (items.isEmpty) return const ListTile(title: Text("Empty"));
            return Column(
              children: items
                  .map((i) => ListTile(
                        title: Text(i.itemName),
                        trailing: Text("x${i.quantity}"),
                        dense: true,
                      ))
                  .toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        )
      ],
    );
  }
}
