import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

// 1. Mock Gemini Service
class MockGeminiService implements GeminiService {
  final Map<String, dynamic> nextStateUpdates;
  final String nextNarrative;

  MockGeminiService({
    this.nextStateUpdates = const {},
    this.nextNarrative = "Mock Narrative",
  });

  @override
  Future<TurnResult> sendMessage(String userMessage, GameDao dao) async {
    return TurnResult(
      narrative: nextNarrative,
      stateUpdates: nextStateUpdates,
    );
  }
}

void main() {
  testWidgets('HP Update Integration Test', (WidgetTester tester) async {
    // 2. Setup In-Memory Database
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // 3. Setup Mock Gemini to deal 1 damage
    final mockGemini = MockGeminiService(
      nextStateUpdates: {'hp_change': -1},
      nextNarrative: "You punch yourself. It hurts.",
    );

    // Seed Database due to Controller refactor removing auto-init
    await db.gameDao.updateCharacterStats(
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

    // 4. Pump Widget with Overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

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
    final char = await db.gameDao.getCharacter();
    expect(char?.currentHp, 9);

    // Cleanup
    await db.close();
  });

  testWidgets('Gold Update Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // Mock Genimi to give 10 gold
    final mockGemini = MockGeminiService(
      nextStateUpdates: {'gold_change': 10},
      nextNarrative: "You find a purse.",
    );

    // Seed Database
    await db.gameDao.updateCharacterStats(
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

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

    final char = await db.gameDao.getCharacter();
    expect(char?.gold, 10);

    await db.close();
  });

  testWidgets('Item Addition Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    final mockGemini = MockGeminiService(
      nextStateUpdates: {
        'add_items': ['Sword']
      },
      nextNarrative: "You find a sword.",
    );

    // Seed Database
    await db.gameDao.updateCharacterStats(
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Inventory Empty
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sword (x1)'), findsNothing);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Perform Action
    await tester.enterText(find.byType(TextField), 'Take sword');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Verify Inventory
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Check for UI update
    expect(find.text('Sword (x1)'), findsOneWidget);

    // Verify DB
    final inventory = await db.gameDao.getInventoryForCharacter(1);
    expect(inventory.length, 1);
    expect(inventory.first.itemName, 'Sword');

    await db.close();
  });

  testWidgets('Item Removal Integration Test', (WidgetTester tester) async {
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    final mockGemini = MockGeminiService(
      nextStateUpdates: {
        'remove_items': ['Potion']
      },
      nextNarrative: "You drink the potion.",
    );

    // Seed Database & Inventory
    await db.gameDao.updateCharacterStats(
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
    await db.gameDao.addItem('Potion');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Inventory Has Potion
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Potion (x1)'), findsOneWidget);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Perform Action
    await tester.enterText(find.byType(TextField), 'Drink potion');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Verify Inventory Empty
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Potion (x1)'), findsNothing);

    // Verify DB
    final inventory = await db.gameDao.getInventoryForCharacter(1);
    expect(inventory.isEmpty, true);

    await db.close();
  });
}
