import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/features/character/widgets/attribute_grid.dart';
import 'package:ttrpg_sim/features/character/widgets/skill_list.dart';
import 'package:ttrpg_sim/features/character/tabs/features_tab.dart';
import 'package:ttrpg_sim/features/character/tabs/grimoire_tab.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';

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

          final bool showMagic = (char.maxMana > 0) ||
              (char.spells.isNotEmpty && char.spells != '[]');

          final List<Widget> tabs = [
            const Tab(icon: Icon(Icons.bar_chart), text: "Stats"),
            if (showMagic)
              const Tab(icon: Icon(Icons.auto_fix_high), text: "Magic"),
            const Tab(icon: Icon(Icons.star), text: "Feats"),
            const Tab(icon: Icon(Icons.backpack), text: "Inv"),
          ];

          final List<Widget> tabViews = [
            // Stats
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      spacing: 16.0,
                      runSpacing: 8.0,
                      children: [
                        Text("HP: ${char.currentHp}/${char.maxHp}",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text("AC: ${char.armorClass}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        Text("Gold: ${char.gold}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AttributeGrid(char: char),
                  ),
                  const Divider(),
                  SkillList(char: char),
                ],
              ),
            ),
            // Magic
            if (showMagic) GrimoireTab(character: char),
            // Features
            FeaturesList(char: char),
            // Inventory
            InventorySection(character: char),
          ];

          return DefaultTabController(
            length: tabs.length,
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
                TabBar(
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  tabs: tabs,
                ),
                Expanded(
                  child: TabBarView(children: tabViews),
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
  final CharacterData character;
  const InventorySection({super.key, required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryDataProvider(character.id));

    final equipment = jsonDecode(character.equipment);

    // Safety check for Map
    final Map<String, dynamic> eqMap =
        (equipment is Map) ? equipment.cast<String, dynamic>() : {};

    final slots = ['mainHand', 'offHand', 'body', 'head', 'accessory'];

    return Column(
      children: [
        // Equipment Grid
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text("Equipment", style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: slots.map((slot) {
            final itemName = eqMap[slot];
            return _buildEquipmentSlot(context, ref, slot, itemName);
          }).toList(),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child:
              Text("Backpack", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      _showInventoryAction(context, ref, i.itemName);
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

  Widget _buildEquipmentSlot(
      BuildContext context, WidgetRef ref, String slot, String? itemName) {
    return GestureDetector(
      onTap: itemName != null ? () => _unequip(context, ref, slot) : null,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: itemName != null
              ? Colors.teal.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(slot.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            if (itemName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(itemName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              )
            else
              const Icon(Icons.add, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showInventoryAction(
      BuildContext context, WidgetRef ref, String itemName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(itemName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Fix: calling provider family with arguments
              // CharacterData should have worldId. If not, we might need to pass it.
              // Assuming CharacterData has worldId as per standard drift generation for FK.
              // If it doesn't (nullable FK), we handle it. But Character.worldId is not nullable in schema?
              // Schema: IntColumn get worldId => integer().nullable().references(...)
              // So it might be nullable. However, for a playable character it should be set.
              if (character.worldId != null) {
                ref
                    .read(
                        gameControllerProvider(character.worldId!, character.id)
                            .notifier)
                    .equipItem(itemName);
              }
            },
            child: const Text("Equip"),
          )
        ],
      ),
    );
  }

  void _unequip(BuildContext context, WidgetRef ref, String slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Unequip $slot?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (character.worldId != null) {
                ref
                    .read(
                        gameControllerProvider(character.worldId!, character.id)
                            .notifier)
                    .unequipItem(slot);
              }
            },
            child: const Text("Unequip"),
          )
        ],
      ),
    );
  }
}
