import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:drift/drift.dart' as drift;

// Mock Gemini Service
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import '../shared_test_utils.dart';

// Mock Gemini Service
class MockGeminiService implements GeminiService {
  @override
  GenerativeModelWrapper createModel(String instruction) {
    throw UnimplementedError();
  }
// ...

  @override
  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String tone,
    required String description,
    required CharacterData player,
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
    String? worldKnowledge,
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

// ... class mock gemini ...

String? _mockModelResponse; // Add if needed or assume mock service

void main() {
  late AppDatabase database;
  late GameDao dao;
  late MockGeminiService mockGemini;

  setUp(() async {
    final mockLoader = MockRuleDataLoader();
    // Cannot set screen size here easily without tester, but Edge Cases usually unit/integration logic
    // But 'Empty Input Guard' uses Controller which might load rules.
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

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
      // Create dummy world for context
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'Test Description',
      ));

      // Create a dummy character
      await dao.updateCharacterStats(CharacterCompanion.insert(
        worldId: drift.Value(worldId),
        name: 'Hero',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 0,
        location: 'Start',
      ));

      // Get the character ID
      final character = await dao.getCharacter(worldId);
      final characterId = character!.id;

      // Setup Controller
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          gameDaoProvider.overrideWithValue(dao),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
      );
      final controller =
          container.read(gameControllerProvider(worldId, characterId).notifier);

      // Wait for initialization to complete
      await container.read(gameControllerProvider(worldId, characterId).future);

      // When: controller.submitAction(" ")
      await controller.submitAction("   ");

      // Then: isLoading should be false
      expect(
          container
              .read(gameControllerProvider(worldId, characterId))
              .isLoading,
          false);

      // Check if any message was inserted into DB.
      // Note: we should use characterId for getRecentMessages now
      final messages = await dao.getRecentMessages(characterId, 10);
      expect(messages.isEmpty, true);
    });
  });
}
