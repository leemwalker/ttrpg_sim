import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'shared_test_utils.dart';

// 1. Mock Gemini Service
class MockGeminiService implements GeminiService {
  @override
  GenerativeModelWrapper createModel(String instruction) {
    throw UnimplementedError();
  }

  final Map<String, dynamic> nextStateUpdates;
  final String nextNarrative;
  final FunctionCall? nextFunctionCall;

  MockGeminiService({
    this.nextStateUpdates = const {},
    this.nextNarrative = "Mock Narrative",
    this.nextFunctionCall,
  });

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
    return TurnResult(
      narrative: nextNarrative,
      stateUpdates: nextStateUpdates,
      functionCall: nextFunctionCall,
    );
  }

  @override
  Future<TurnResult> sendFunctionResponse(
    String functionName,
    Map<String, dynamic> response,
  ) async {
    // Return the same next state/narrative for simplicity in tests,
    // or we could add specific fields for function response if needed.
    return TurnResult(
      narrative: nextNarrative,
      stateUpdates: nextStateUpdates,
      functionCall: nextFunctionCall,
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    final mockLoader = MockRuleDataLoader();
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);
  });

  testWidgets('HP Update Integration Test', (WidgetTester tester) async {
    // 2. Setup In-Memory Database
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    // 3. Setup Mock Gemini to deal 1 damage
    final mockGemini = MockGeminiService(
      nextStateUpdates: {'hp_change': -1},
      nextNarrative: "You punch yourself. It hurts.",
    );

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Test',
      description: 'Test Description',
    ));

    // Seed Database due to Controller refactor removing auto-init
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(1),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    // Seed message to prevent Session Zero auto-trigger
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    // 4. Pump Widget with Overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen(worldId: 1, characterId: 1)),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    // 5. Initial Load (Wait for "First Run" init)
    await tester.pumpAndSettle();

    // Verify Initial State (HP 10)
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('HP: 10/10'), findsOneWidget);

    // Close Drawer
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // 6. Perform Action
    await tester.enterText(find.byType(TextField), 'Punch myself');
    await tester.tap(find.byIcon(Icons.send));

    // 7. Verify Loading State
    await tester.pump(); // Start request
    // Note: We might see loading indicator

    // 8. Wait for settlement (Async operations)
    await tester.pumpAndSettle();

    // 9. Verify Final State in UI (HP should be 9)
    // The text on screen might be in the drawer, which isn't open.
    // Let's open the drawer to check.
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('HP: 9/10'), findsOneWidget);

    // 10. Verify DB State directly
    final char = await db.gameDao.getCharacter(worldId);
    expect(char?.currentHp, 9);

    // Cleanup
    await db.close();
  });

  testWidgets('Gold Update Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    // Mock Genimi to give 10 gold
    final mockGemini = MockGeminiService(
      nextStateUpdates: {'gold_change': 10},
      nextNarrative: "You find a purse.",
    );

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Test',
      description: 'Test Description',
    ));

    // Seed Database
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(1),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen(worldId: 1, characterId: 1)),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    await tester.pumpAndSettle(); // Init

    // Open Drawer to check initial gold
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Gold: 0'), findsOneWidget);

    // Close Drawer (tap outside)
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Perform Action
    await tester.enterText(find.byType(TextField), 'Search room');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Open Drawer again
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Gold: 10'), findsOneWidget);

    final char = await db.gameDao.getCharacter(worldId);
    expect(char?.gold, 10);

    await db.close();
  });

  testWidgets('Item Addition Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    final mockGemini = MockGeminiService(
      nextStateUpdates: {
        'add_items': ['Sword']
      },
      nextNarrative: "You find a sword.",
    );

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Test',
      description: 'Test Description',
    ));

    // Seed Database
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(1),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen(worldId: 1, characterId: 1)),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    await tester.pumpAndSettle();

    // Verify Inventory Empty
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    // Tap Inv Tab
    await tester.tap(find.text('Inv'));
    await tester.pumpAndSettle();

    expect(find.text('Sword (x1)'), findsNothing);

    // Close Drawer
    await tester.dragFrom(
        tester.getTopRight(find.byType(MaterialApp)), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Perform Action
    await tester.enterText(find.byType(TextField), 'Take sword');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Verify Inventory (Re-open drawer)
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(600, 0));
    await tester.pumpAndSettle();

    // Tap Inv Tab
    await tester.tap(find.text('Inv'));
    await tester.pumpAndSettle();

    // Check for UI update
    expect(find.text('Sword'), findsOneWidget);
    expect(find.text('x1'), findsOneWidget);

    // Verify DB
    final char = await db.gameDao.getCharacter(worldId);
    final inventory = await db.gameDao.getInventoryForCharacter(char!.id);
    expect(inventory.length, 1);
    expect(inventory.first.itemName, 'Sword');

    await db.close();
  });

  testWidgets('Item Removal Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    final mockGemini = MockGeminiService(
      nextStateUpdates: {
        'remove_items': ['Potion']
      },
      nextNarrative: "You drink the potion.",
    );

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Test',
      description: 'Test Description',
    ));

    // Seed Database & Inventory
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(1),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    // Helper to get seeded char id
    final char = await db.gameDao.getCharacter(worldId);
    await db.gameDao.addItem(char!.id, 'Potion');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen(worldId: 1, characterId: 1)),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    await tester.pumpAndSettle();

    // Verify Inventory Has Potion
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Tap Inventory Tab
    await tester.tap(find.text('Inv'));
    await tester.pumpAndSettle();

    expect(find.text('Potion'), findsOneWidget);
    expect(find.text('x1'), findsOneWidget);
    await tester.tapAt(const Offset(400, 300)); // Tap to close drawer/interact?
    // Wait, drawer covers screen. Tapping X/Y might hit something.
    // If I want to close drawer I should tap outside or drag back.
    // But the test continues to "Perform Action".
    // I need to close drawer to type in main screen.
    await tester.dragFrom(tester.getTopRight(find.byType(MaterialApp)),
        const Offset(-300, 0)); // Close drawer?
    // Or just tap outside.
    await tester.pumpAndSettle();

    // Perform Action
    await tester.enterText(find.byType(TextField), 'Drink potion');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Verify Inventory Empty (Re-open drawer)
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Tap Inventory Tab again (state might reset if drawer rebuilt, but usually controller persists or defaults)
    await tester.tap(find.text('Inv'));
    await tester.pumpAndSettle();

    expect(find.text('Potion'), findsNothing);

    // Verify DB
    final inventory = await db.gameDao.getInventoryForCharacter(char.id);
    expect(inventory.isEmpty, true);

    await db.close();
  });

  test('Atlas System CRUD', () async {
    // Setup in-memory database
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // 1. Create a World
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'A test world for Atlas System',
    ));
    expect(worldId, greaterThan(0));

    // 2. Create a Location linked to that World
    final locationId =
        await db.gameDao.createLocation(LocationsCompanion.insert(
      worldId: worldId,
      name: 'Riverwood',
      description: 'A small village by the river',
      type: 'Village',
      coordinates: const Value('0,1'),
    ));
    expect(locationId, greaterThan(0));

    // 3. Verify the Location can be fetched
    final fetchedLocation = await db.gameDao.getLocation(locationId);
    expect(fetchedLocation, isNotNull);
    expect(fetchedLocation!.name, 'Riverwood');
    expect(fetchedLocation.type, 'Village');
    expect(fetchedLocation.worldId, worldId);

    // 4. Create a POI linked to that Location
    final poiId = await db.gameDao.createPoi(PointsOfInterestCompanion.insert(
      locationId: locationId,
      name: 'The Sleeping Giant Inn',
      description: 'A cozy tavern with warm food',
      type: 'Tavern',
    ));
    expect(poiId, greaterThan(0));

    // 5. Create an NPC linked to the Location and POI
    final npcId = await db.gameDao.createNpc(NpcsCompanion.insert(
      worldId: worldId,
      locationId: Value(locationId),
      poiId: Value(poiId),
      name: 'Orgnar',
      role: 'Innkeeper',
      description: 'A gruff but friendly Nord who runs the inn',
    ));
    expect(npcId, greaterThan(0));

    // 6. Verify POIs for Location
    final pois = await db.gameDao.getPoisForLocation(locationId);
    expect(pois.length, 1);
    expect(pois.first.name, 'The Sleeping Giant Inn');

    // 7. Verify NPCs for Location
    final npcs = await db.gameDao.getNpcsForLocation(locationId);
    expect(npcs.length, 1);
    expect(npcs.first.name, 'Orgnar');
    expect(npcs.first.role, 'Innkeeper');

    // 8. Create a Character and update their location
    await db.gameDao.updateCharacterStats(
      CharacterCompanion(
        id: const Value(1),
        name: const Value('TestHero'),
        level: const Value(1),
        currentHp: const Value(10),
        maxHp: const Value(10),
        gold: const Value(0),
        location: const Value('Unknown'),
        worldId: Value(worldId),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    final charBefore = await db.gameDao.getCharacter(worldId);
    expect(charBefore, isNotNull);
    expect(charBefore!.currentLocationId, isNull);

    // 9. Update character's location
    await db.gameDao.updateCharacterLocation(charBefore.id, locationId);

    final charAfter = await db.gameDao.getCharacter(worldId);
    expect(charAfter, isNotNull);
    expect(charAfter!.currentLocationId, locationId);

    // Cleanup
    await db.close();
  });

  test('Location Generation via Function Call', () async {
    // Setup in-memory database
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // 1. Create a World
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'A test world for function calling',
    ));

    // 2. Create a Character without a location
    await db.gameDao.updateCharacterStats(
      CharacterCompanion(
        id: const Value(1),
        name: const Value('TestHero'),
        level: const Value(1),
        currentHp: const Value(10),
        maxHp: const Value(10),
        gold: const Value(0),
        location: const Value('Unknown'),
        worldId: Value(worldId),
      ),
    );
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    // Verify character has no location initially
    final charBefore = await db.gameDao.getCharacter(worldId);
    expect(charBefore, isNotNull);
    expect(charBefore!.currentLocationId, isNull);

    // 3. Simulate function call data (what Gemini would return)
    final mockFunctionArgs = {
      'name': 'Riverwood',
      'description': 'A small village nestled by the river',
      'type': 'Village',
      'pois': [
        {
          'name': 'The Sleeping Giant Inn',
          'type': 'Tavern',
          'description': 'A cozy tavern with warm food',
        },
        {
          'name': 'Riverwood Trader',
          'type': 'Shop',
          'description': 'General goods store',
        },
      ],
      'npcs': [
        {
          'name': 'Orgnar',
          'role': 'Innkeeper',
          'description': 'A gruff but friendly Nord',
        },
      ],
    };

    // 4. Create the location (simulating what GameController does)
    final locationId =
        await db.gameDao.createLocation(LocationsCompanion.insert(
      worldId: worldId,
      name: mockFunctionArgs['name'] as String,
      description: mockFunctionArgs['description'] as String,
      type: mockFunctionArgs['type'] as String,
    ));
    expect(locationId, greaterThan(0));

    // 5. Create POIs
    final poisData = mockFunctionArgs['pois'] as List<dynamic>;
    for (final poi in poisData) {
      if (poi is Map<String, dynamic>) {
        await db.gameDao.createPoi(PointsOfInterestCompanion.insert(
          locationId: locationId,
          name: poi['name'] as String,
          description: poi['description'] as String,
          type: poi['type'] as String,
        ));
      }
    }

    // 6. Create NPCs
    final npcsData = mockFunctionArgs['npcs'] as List<dynamic>;
    for (final npc in npcsData) {
      if (npc is Map<String, dynamic>) {
        await db.gameDao.createNpc(NpcsCompanion.insert(
          worldId: worldId,
          locationId: Value(locationId),
          name: npc['name'] as String,
          role: npc['role'] as String,
          description: npc['description'] as String,
        ));
      }
    }

    // 7. Update character location
    await db.gameDao.updateCharacterLocation(charBefore.id, locationId);

    // 8. Verify location was created
    final location = await db.gameDao.getLocation(locationId);
    expect(location, isNotNull);
    expect(location!.name, 'Riverwood');
    expect(location.type, 'Village');

    // 9. Verify POIs were created
    final pois = await db.gameDao.getPoisForLocation(locationId);
    expect(pois.length, 2);
    expect(
        pois.map((p) => p.name).toList(), contains('The Sleeping Giant Inn'));
    expect(pois.map((p) => p.name).toList(), contains('Riverwood Trader'));

    // 10. Verify NPCs were created
    final npcs = await db.gameDao.getNpcsForLocation(locationId);
    expect(npcs.length, 1);
    expect(npcs.first.name, 'Orgnar');
    expect(npcs.first.role, 'Innkeeper');

    // 11. Verify character location was updated
    final charAfter = await db.gameDao.getCharacter(worldId);
    expect(charAfter, isNotNull);
    expect(charAfter!.currentLocationId, locationId);

    // Cleanup
    await db.close();
  });
}
