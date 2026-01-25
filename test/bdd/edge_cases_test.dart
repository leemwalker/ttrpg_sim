import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:drift/drift.dart' as drift;

// Mock Gemini Service
import 'package:ttrpg_sim/core/services/gemini_service.dart';

// Mock Gemini Service
class MockGeminiService implements GeminiService {
  @override
  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String description,
    required CharacterData player,
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
  }) async {
    return Future.value(
        TurnResult(narrative: 'Mock Response', stateUpdates: {}));
  }

  @override
  Future<TurnResult> sendFunctionResponse(
      String functionName, Map<String, dynamic> response) async {
    return Future.value(
        TurnResult(narrative: 'Mock Function Response', stateUpdates: {}));
  }
}

void main() {
  late AppDatabase database;
  late GameDao dao;
  late MockGeminiService mockGemini;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    // Ensure FKs are enabled for the test
    await database.customStatement('PRAGMA foreign_keys = ON');
    dao = GameDao(database);
    mockGemini = MockGeminiService();
  });

  tearDown(() async {
    await database.close();
  });

  group('Edge Cases', () {
    test('Scenario: Cascading Delete', () async {
      // Given: A World, Character, and Location exist
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'Test Description',
      ));

      await dao.updateCharacterStats(CharacterCompanion.insert(
        worldId: drift.Value(worldId),
        name: 'Hero',
        heroClass: 'Fighter',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 0,
        location: 'Start',
      ));

      await dao.createLocation(LocationsCompanion.insert(
        worldId: worldId,
        name: 'Test Location',
        description: 'Desc',
        type: 'Town',
      ));

      // Verify creation
      expect((await dao.getCharacter(worldId)) != null, true);
      expect((await dao.getLocationsForWorld(worldId)).length, 1);

      // When: dao.deleteWorld(worldId)
      await dao.deleteWorld(worldId);

      // Then: Characters and Locations should be empty
      expect(await dao.getCharacter(worldId), null);
      expect((await dao.getLocationsForWorld(worldId)).isEmpty, true);
    });

    test('Scenario: Empty Input Guard', () async {
      // Setup Controller
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          gameDaoProvider.overrideWithValue(dao),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
      );
      final controller = container.read(gameControllerProvider.notifier);

      // Create dummy world for context
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'Test Description',
      ));

      // When: controller.submitAction(" ")
      await controller.submitAction("   ", worldId);

      // Then: isLoading should be false (it initializes as false)
      expect(container.read(gameControllerProvider).isLoading, false);

      // And Mock Gemini sendMessage should NEVER be called
      // Since we didn't train the mock to record calls, checking side effects is hard without a spy.
      // But if it WAS called, the state would surely update or we'd see logs if we had a real logger.
      // Better verification: Check if any message was inserted into DB.
      // If controller ran, it would insert a user message "   ".
      // If guarded, no message inserted.
      final messages = await dao.getRecentMessages(10);
      expect(messages.isEmpty, true);
    });
  });
}
