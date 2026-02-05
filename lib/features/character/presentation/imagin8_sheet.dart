import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/character/presentation/widgets/imagin8_card_widget.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:ttrpg_sim/core/services/backup_service.dart';

// Provider helper to fetch cards by ID list
// We use String (JSON) instead of List<int> to ensure provider stability
// because Lists use referential equality and will cause infinite rebuild loops.
final resolvedCardsProvider =
    FutureProvider.family<List<Imagin8Card>, String>((ref, jsonStr) async {
  // Be robust: some legacy snapshots might store IDs as strings in the JSON list
  final rawList = jsonDecode(jsonStr) as List;
  final ids = rawList.map((e) => int.parse(e.toString())).toList();

  if (ids.isEmpty) return [];
  final dao = ref.watch(gameDaoProvider);
  final List<Imagin8Card> cards = [];
  for (final id in ids) {
    final card = await dao.getImagin8Card(id);
    if (card != null) cards.add(card);
  }
  return cards;
});

class Imagin8Sheet extends ConsumerWidget {
  final CharacterData character;

  const Imagin8Sheet({super.key, required this.character});

  void _showPlayDialog(BuildContext context, WidgetRef ref, Imagin8Card card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Play ${card.name}?"),
        content: const Text(
            "This will move the card to your discard pile and post it to the narrative."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref
                  .read(gameControllerProvider(character.worldId!, character.id)
                      .notifier)
                  .playImagin8Card(card.id);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text("Play Card"),
          ),
        ],
      ),
    );
  }

  void _showRecoverDialog(
      BuildContext context, WidgetRef ref, Imagin8Card card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Recover ${card.name}?"),
        content: const Text("Bring this single card back to your hand?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(gameControllerProvider(character.worldId!, character.id)
                      .notifier)
                  .recoverImagin8Card(card.id);
            },
            child: const Text("Recover"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handStr = character.hand ?? '[]';
    final discardStr = character.discardPile ?? '[]';

    final handAsync = ref.watch(resolvedCardsProvider(handStr));
    final discardAsync = ref.watch(resolvedCardsProvider(discardStr));

    // For the UI count labels, also be robust
    final handIds =
        (jsonDecode(handStr) as List).map((e) => e.toString()).toList();
    final discardIds =
        (jsonDecode(discardStr) as List).map((e) => e.toString()).toList();

    return Column(
      children: [
        // --- HAND SECTION ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text("Hand (${handIds.length})",
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (discardIds.isNotEmpty)
                IconButton(
                  tooltip: "Recover All (New Scene)",
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref
                        .read(gameControllerProvider(
                                character.worldId!, character.id)
                            .notifier)
                        .recoverAllImagin8Cards();
                  },
                ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: handAsync.when(
            data: (cards) {
              if (cards.isEmpty) {
                return const Center(child: Text("Hand is empty. Recover?"));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return Imagin8CardWidget(
                    card: card,
                    onTap: () => _showPlayDialog(context, ref, card),
                  );
                },
              );
            },
            loading: () => const Center(child: Text("Loading cards...")),
            error: (e, s) => Center(child: Text("Error: $e")),
          ),
        ),

        const Divider(),

        // --- ACTIONS ---
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(
                        gameControllerProvider(character.worldId!, character.id)
                            .notifier)
                    .rollImagin8Die(8);
              },
              icon: const Icon(Icons.casino),
              label: const Text("Roll d8"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(
                        gameControllerProvider(character.worldId!, character.id)
                            .notifier)
                    .rollImagin8Die(6);
              },
              icon: const Icon(Icons.casino),
              label: const Text("Roll d6"),
            ),
          ],
        ),

        const Divider(),

        // --- DISCARD PILE ---
        Expanded(
          child: ExpansionTile(
            title: Text("Discard Pile (${discardIds.length})"),
            initiallyExpanded: false,
            children: [
              discardAsync.when(
                data: (cards) {
                  if (cards.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No discarded cards."),
                    );
                  }
                  return SizedBox(
                    height: 200, // Constrained height for expanded list
                    child: ListView.builder(
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return ListTile(
                          title: Text(card.name),
                          subtitle: Text(card.type),
                          trailing: IconButton(
                            icon: const Icon(Icons.restore),
                            onPressed: () =>
                                _showRecoverDialog(context, ref, card),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Text("Loading discarded..."),
                error: (e, s) => Text("Error: $e"),
              ),
            ],
          ),
        ),

        const Divider(),
        ListTile(
          leading: const Icon(Icons.share),
          title: const Text("Export Campaign"),
          onTap: () async {
            // Close drawer
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Preparing backup...")));

            try {
              final db = ref.read(databaseProvider);
              await BackupService(db).exportCampaign(character.worldId!);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Export failed: $e"),
                  backgroundColor: Colors.red));
            }
          },
        ),
      ],
    );
  }
}
