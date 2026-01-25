import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';

part 'game_controller.g.dart';

@riverpod
class GameController extends _$GameController {
  @override
  Future<GameState> build() async {
    final dao = ref.read(gameDaoProvider);
    final messages = await dao.getRecentMessages(50);
    return GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
    );
  }

  Future<void> submitAction(String text, int worldId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final dao = ref.read(gameDaoProvider);
      final gemini = ref.read(geminiServiceProvider);
      final db = ref.read(databaseProvider);
      print(
          '🎮 CONTROLLER using DB Instance: ${db.instanceId} for World $worldId');

      // Save user message (Global chat for now as per schema)
      await dao.insertMessage('user', text);

      // Fetch World Context
      final world = await dao.getWorld(worldId);
      final genre = world?.genre ?? "Fantasy";
      final description = world?.description ?? "A standard fantasy world.";

      // Fetch Character
      final character = await dao.getCharacter(worldId);
      if (character == null) {
        throw Exception('No character found for world $worldId');
      }

      // Call Gemini
      final result = await gemini.sendMessage(
        text,
        dao,
        worldId,
        genre: genre,
        description: description,
        player: character,
      );

      print('🎮 CONTROLLER: Received updates: ${result.stateUpdates}');

      // Apply Updates (Additive Math)
      if (result.stateUpdates.isNotEmpty) {
        final currentCharacter = await dao.getCharacter(worldId);
        if (currentCharacter != null) {
          final updates = result.stateUpdates;

          if (updates.containsKey('hp_change')) {
            final change = updates['hp_change'];
            if (change != null && change is int) {
              // 1. Fetch the LATEST fresh copy of the character
              final freshChar = await dao.getCharacter(worldId);
              if (freshChar != null) {
                // 2. Calculate new HP
                final currentHp = freshChar.currentHp;
                // Ensure we don't go below 0 or above Max
                final newHp = (currentHp + change).clamp(0, freshChar.maxHp);
                final charId = freshChar.id;

                print('⚡ RAW SQL: Forcing update for ID $charId to HP $newHp');

                // 3. Execute Raw SQL
                await dao.forceUpdateHp(charId, newHp);

                // 4. Verify immediately
                final verification = await dao.getCharacter(worldId);
                if (verification?.currentHp == newHp) {
                  print(
                      '✅ VERIFIED: DB now holds HP ${verification?.currentHp}');
                } else {
                  print(
                      '❌ CRITICAL FAILURE: DB still holds HP ${verification?.currentHp}');
                }

                // 5. Refresh UI
                ref.invalidate(characterDataProvider(worldId));
              }
            }
          }

          if (updates.containsKey('gold_change')) {
            final change = updates['gold_change'] as int? ?? 0;
            final newGold = currentCharacter.gold + change;
            await dao.updateGold(currentCharacter.id, newGold);
          }

          if (updates.containsKey('location_update')) {
            final newLoc = updates['location_update'] as String?;
            if (newLoc != null) {
              await dao.updateLocation(currentCharacter.id, newLoc);
            }
          }

          // Refresh context
          if (result.stateUpdates.containsKey('add_items')) {
            final items = result.stateUpdates['add_items'] as List<dynamic>?;
            if (items != null) {
              for (final item in items) {
                await dao.addItem(currentCharacter.id, item as String);
              }
            }
          }

          if (result.stateUpdates.containsKey('remove_items')) {
            final items = result.stateUpdates['remove_items'] as List<dynamic>?;
            if (items != null) {
              for (final item in items) {
                await dao.removeItem(currentCharacter.id, item as String);
              }
            }
          }
        }
      }

      // FORCE REFRESH: Tell the UI stream to re-fetch data immediately
      await Future.delayed(const Duration(milliseconds: 50)); // The "Breath"
      ref.invalidate(characterDataProvider(worldId));
      ref.invalidate(inventoryDataProvider(
          await dao.getCharacter(worldId).then((c) => c?.id ?? -1)));
      // Note: Invalidating inventory requires charId. We fetch it again or cache it.
      // Simplified: Just invalidate the specific provider if we knew the ID, but here we re-fetch to be safe or just don't invalidate if null.
      // Better approach:
      final c = await dao.getCharacter(worldId);
      if (c != null) {
        ref.invalidate(inventoryDataProvider(c.id));
      }

      print('🔄 CONTROLLER: Invalidated Streams to force UI update.');

      // Save AI message
      await dao.insertMessage('ai', result.narrative);

      // Reload messages
      final messages = await dao.getRecentMessages(50);
      return GameState(
        messages: messages,
        character: null,
        inventory: [],
        isLoading: false,
      );
    });
  }
}
