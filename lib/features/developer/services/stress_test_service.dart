import 'package:drift/drift.dart';
import 'package:ttrpg_sim/core/database/database.dart';

class StressTestService {
  final GameDao _dao;

  StressTestService(this._dao);

  Future<void> generateCampaignData({
    required int turnCount,
    required int worldId,
    required int characterId,
  }) async {
    const int chunkSize = 500;

    for (int i = 0; i < turnCount; i += chunkSize) {
      final int end = (i + chunkSize < turnCount) ? i + chunkSize : turnCount;

      await _dao.batch((batch) {
        for (int j = i; j < end; j++) {
          // User Message
          batch.insert(
            _dao.chatMessages,
            ChatMessagesCompanion.insert(
              role: MessageRole.user,
              content: "Action $j: I attack the darkness!",
              worldId: Value(worldId),
              characterId: Value(characterId),
              timestamp: Value(DateTime.now().add(Duration(seconds: j * 2))),
            ),
          );

          // AI Response
          batch.insert(
            _dao.chatMessages,
            ChatMessagesCompanion.insert(
              role: MessageRole.ai,
              content:
                  "Narrative response $j: The darkness absorbs your attack. "
                  "You feel a chill run down your spine as the shadows deepen. "
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
                  "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
              worldId: Value(worldId),
              characterId: Value(characterId),
              timestamp:
                  Value(DateTime.now().add(Duration(seconds: j * 2 + 1))),
            ),
          );
        }
      });
    }
  }

  Future<void> populateWorld({
    required int locationCount,
    required int npcCount,
    required int worldId,
  }) async {
    const int chunkSize = 500;

    // 1. Locations
    // final List<int> locationIds = [];

    for (int i = 0; i < locationCount; i += chunkSize) {
      // We can't easily get IDs back from batch inserts efficiently in all drivers without returning,
      // but for populating NPCs we need location IDs.
      // So we might need to insert locations one by one or in smaller batches if we need IDs?
      // OR we just batch insert them and then fetch them all back.
      // Fetching back is safer for batching.

      final int end =
          (i + chunkSize < locationCount) ? i + chunkSize : locationCount;
      await _dao.batch((batch) {
        for (int j = i; j < end; j++) {
          batch.insert(
            _dao.locations,
            LocationsCompanion.insert(
              worldId: worldId,
              name: "Generated Location $j",
              description: "A procedurally generated test location number $j.",
              type: "Forest",
            ),
          );
        }
      });
    }

    // Fetch all locations to distribute NPCs
    final locations = await _dao.getLocationsForWorld(worldId);
    if (locations.isEmpty) return;

    // 2. NPCs
    for (int i = 0; i < npcCount; i += chunkSize) {
      final int end = (i + chunkSize < npcCount) ? i + chunkSize : npcCount;

      await _dao.batch((batch) {
        for (int j = i; j < end; j++) {
          final loc = locations[j % locations.length];
          batch.insert(
            _dao.npcs,
            NpcsCompanion.insert(
              worldId: worldId,
              locationId: Value(loc.id),
              name: "Test NPC $j",
              role: "Villager",
              description: "A generic NPC for stress testing.",
            ),
          );
        }
      });
    }
  }

  Future<void> spamQuests({
    required int count,
    required int worldId,
  }) async {
    const int chunkSize = 500;

    for (int i = 0; i < count; i += chunkSize) {
      final int end = (i + chunkSize < count) ? i + chunkSize : count;

      await _dao.batch((batch) {
        for (int j = i; j < end; j++) {
          final isCompleted = j % 2 == 0;
          batch.insert(
            _dao.quests,
            QuestsCompanion.insert(
              worldId: worldId,
              title: "Test Quest $j",
              status: isCompleted ? 'completed' : 'active',
              description: "This is a generated quest to test UI rendering.",
            ),
          );
        }
      });
    }
  }
}
