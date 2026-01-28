import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'mock_gemini_service.dart';

void main() {
  testWidgets('BDD Scenario: AI Updates Game State (HP, Gold, Inventory)',
      (WidgetTester tester) async {
    // GIVEN I have a character with known stats
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Hero'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Start'),
        worldId: Value(worldId),
      ),
    );

    // Seed messages to bypass Session Zero
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);
    await db.gameDao.insertMessage('system', 'Welcome', worldId, 1);

    // AND The AI is mocked to return multiple state updates
    final mockGemini = MockGeminiService(
      nextNarrative: "You find a potion and some gold!",
      nextStateUpdates: {
        'hp_change': -2, // Took damage
        'gold_change': 50, // Found gold
        'add_items': ['Health Potion'], // Found item
      },
    );

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

    // WHEN I trigger the AI response (send a message)
    await tester.enterText(find.byType(TextField), "Look around");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // THEN The UI should reflect the new Narrative
    expect(find.textContaining('You find a potion and some gold!'),
        findsOneWidget);

    // AND The Database should be updated
    final char = await db.gameDao.getCharacter(worldId);
    expect(char!.currentHp, 8, reason: 'HP should decrease by 2');
    expect(char.gold, 50, reason: 'Gold should increase by 50');

    final inventory = await db.gameDao.getInventoryForCharacter(char.id);
    expect(inventory, hasLength(1));
    expect(inventory.first.itemName, 'Health Potion');

    await db.close();
  });
}
