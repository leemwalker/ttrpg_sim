import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'mock_gemini_service.dart';

void main() {
  testWidgets('BDD Scenario: Hero Dies', (WidgetTester tester) async {
    // SETUP
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test Realm',
      genre: 'Dark Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(CharacterCompanion.insert(
      worldId: Value(worldId),
      name: 'Victim',
      heroClass: 'Peasant',
      level: 1,
      currentHp: 5, // Weak
      maxHp: 10,
      gold: 0,
      location: 'Dungeon',
    ));

    // Mock Gemini to "kill" the player
    // The controller calculates HP changes based on stateUpdates.
    // We want the AI to return hp_change: -10
    final mockGemini = MockGeminiService();
    mockGemini.nextNarrative = "The dragon breathes fire. You are incinerated.";
    mockGemini.nextStateUpdates = {
      'hp_change': -10
    }; // 5 - 10 = -5 -> 0 (clamped)

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: MaterialApp(
          home: GameScreen(worldId: worldId, characterId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I take 10 damage via AI event (simulated by user input prompting response)
    await tester.enterText(find.byType(TextField), "I attack the dragon");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pumpAndSettle();

    // THEN HP should be 0
    final char = await db.gameDao.getCharacter(worldId);
    expect(char!.currentHp, 0);

    // AND (Optional) UI might show status?
    // We rely on the narrative content for now, but checking DB is the robust persistence check.
    expect(find.textContaining('incinerated'), findsWidgets);

    await db.close();
  });
}
