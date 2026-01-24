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
    return _loadState();
  }

  Future<GameState> _loadState() async {
    final dao = ref.read(gameDaoProvider);

    // Initialization Guard
    var character = await dao.getCharacter();
    if (character == null) {
      // First run: Create default character
      await dao.updateCharacterStats(
        const CharacterCompanion(
          name: Value('Traveler'),
          heroClass: Value('Adventurer'),
          level: Value(1),
          currentHp: Value(10),
          maxHp: Value(10),
          gold: Value(0),
          location: Value('Unknown'),
        ),
      );

      // Insert welcome message
      await dao.insertMessage('ai', 'Welcome to the world. Who are you?');

      // Fetch again
      character = await dao.getCharacter();
    }

    final messages = await dao.getRecentMessages(50);
    final inventory = await dao.getInventory();

    // Reverse messages for UI if we display reversed, but let's just reverse them here if we want chronological or not.
    // Usually chat is bottom-up.

    return GameState(
      messages: messages,
      character: character,
      inventory: inventory,
      isLoading: false,
    );
  }

  Future<void> submitAction(String text) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final dao = ref.read(gameDaoProvider);
      final gemini = ref.read(geminiServiceProvider);

      // Save user message
      await dao.insertMessage('user', text);

      // Call Gemini
      final result = await gemini.sendMessage(text, dao);

      // Apply Updates (Additive Math)
      if (result.stateUpdates.isNotEmpty) {
        final currentCharacter = await dao.getCharacter();
        if (currentCharacter != null) {
          final updates = result.stateUpdates;

          if (updates.containsKey('hp_change')) {
            final change = updates['hp_change'] as int? ?? 0;
            final newHp = (currentCharacter.currentHp + change)
                .clamp(0, currentCharacter.maxHp);
            await dao.updateCharacterStats(currentCharacter
                .toCompanion(true)
                .copyWith(currentHp: Value(newHp)));
          }

          if (updates.containsKey('gold_change')) {
            final change = updates['gold_change'] as int? ?? 0;
            final newGold = currentCharacter.gold +
                change; // Allow debt? assuming yes or handle check
            await dao.updateCharacterStats(currentCharacter
                .toCompanion(true)
                .copyWith(gold: Value(newGold)));
          }

          if (updates.containsKey('location_update')) {
            final newLoc = updates['location_update'] as String?;
            if (newLoc != null) {
              await dao.updateCharacterStats(currentCharacter
                  .toCompanion(true)
                  .copyWith(location: Value(newLoc)));
            }
          }

          // Refresh context likely needed if items change logic depends on it, but we reload at end.
        }

        if (result.stateUpdates.containsKey('add_items')) {
          final items = result.stateUpdates['add_items'] as List<dynamic>?;
          if (items != null) {
            for (final item in items) {
              await dao.addItem(item as String);
            }
          }
        }

        if (result.stateUpdates.containsKey('remove_items')) {
          final items = result.stateUpdates['remove_items'] as List<dynamic>?;
          if (items != null) {
            for (final item in items) {
              await dao.removeItem(item as String);
            }
          }
        }
      }

      // Save AI message
      await dao.insertMessage('ai', result.narrative);

      return _loadState();
    });
  }
}
