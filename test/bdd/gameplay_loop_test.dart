import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';

// Smart Mock for Sequencing Responses
class SmartMockGemini implements GeminiService {
  @override
  GenerativeModelWrapper createModel(String instruction) {
    throw UnimplementedError();
  }

  final List<TurnResult> responses;
  int _index = 0;

  SmartMockGemini(this.responses);

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
  }) async {
    if (_index >= responses.length) {
      return TurnResult(
          narrative: "Error: No more responses", stateUpdates: {});
    }
    return responses[_index++];
  }

  @override
  Future<TurnResult> sendFunctionResponse(
    String functionName,
    Map<String, dynamic> response,
  ) async {
    if (_index >= responses.length) {
      return TurnResult(
          narrative: "Error: No more responses", stateUpdates: {});
    }
    return responses[_index++];
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  testWidgets('BDD Scenario: Session Zero (Genesis Mode)',
      (WidgetTester tester) async {
    // GIVEN I have a new character with no location (currentLocationId is null)
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    // Seed World & Character
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        id: Value(1),
        name: Value('Traveler'),
        heroClass: Value('Fighter'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(worldId),
        // currentLocationId is null by default
      ),
    );

    // AND The AI tool generate_location is mocked to return "The Rusty Anchor"
    final mockGemini = SmartMockGemini([
      TurnResult(
        narrative:
            "Generating location...", // Narrative ignored during function call in controller usually, but stored?
        stateUpdates: {},
        functionCall: FunctionCall(
          'generate_location',
          {
            'name': 'The Rusty Anchor',
            'description': 'A salty tavern.',
            'type': 'Tavern'
          },
        ),
      ),
    ]);

    // Pump App
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(
          home: GameScreen(worldId: worldId, characterId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I send the message "I start in a tavern"
    await tester.enterText(find.byType(TextField), "I start in a tavern");
    await tester.tap(find.byIcon(Icons.send));
    // Wait longer for async DB ops
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // THEN The Locations table should contain "The Rusty Anchor"
    final locations = await db.gameDao.getLocationsForWorld(worldId);
    expect(locations, isNotEmpty);
    expect(locations.first.name, 'The Rusty Anchor');

    // AND The Character's currentLocationId should be updated
    final char = await db.gameDao.getCharacter(worldId);
    expect(char!.currentLocationId, locations.first.id);

    // AND The UI should verify receipt (we check the chat log for the generated narrative)
    // Controller generates narrative: 'You arrive at **The Rusty Anchor**. A salty tavern.'
    expect(find.textContaining('You arrive at **The Rusty Anchor**'),
        findsOneWidget);

    await db.close();
  });

  testWidgets('BDD Scenario: Dice Engine (Skill Check)',
      (WidgetTester tester) async {
    // GIVEN My character has 16 Strength (+3 Modifier)
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        id: Value(1),
        name: Value('Strongman'),
        heroClass: Value('Fighter'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0), // Required
        strength: Value(16), // +3
        worldId: Value(worldId),
        location: Value('Unknown'),
      ),
    );

    // AND The AI tool roll_check is mocked to request a "Strength" check (DC 10)
    final mockGemini = SmartMockGemini([
      // 1. Initial response to user input -> Function Call
      TurnResult(
        narrative: "",
        stateUpdates: {},
        functionCall: FunctionCall(
          'roll_check',
          {'check_name': 'strength', 'difficulty': 10},
        ),
      ),
      // 2. Response after function execution (Narrative)
      TurnResult(
        narrative: "You lift the rock easily.",
        stateUpdates: {},
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(
          home: GameScreen(worldId: worldId, characterId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I send the action "I lift the heavy rock"
    await tester.enterText(find.byType(TextField), "I lift the heavy rock");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(); // Start
    await tester.pumpAndSettle(); // Finish

    // Verify DB contains System Message for Roll
    final messages = await db.gameDao.getRecentMessages(1, 10);
    // Find system message
    final systemMsg = messages.firstWhere((m) => m.role.name == 'system');
    expect(systemMsg.content, contains('Roll:'));
    expect(systemMsg.content, contains('+ 3'));
    expect(systemMsg.content, contains('vs DC 10'));

    // Also verify final narrative
    expect(find.text('You lift the rock easily.'), findsOneWidget);

    await db.close();
  });
}
