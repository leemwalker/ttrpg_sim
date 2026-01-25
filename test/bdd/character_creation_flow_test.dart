import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

void main() {
  testWidgets('BDD Scenario: Create Character', (WidgetTester tester) async {
    // GIVEN I am on the Character Creation screen for a new world
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    final worldId = 1;

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
    ));
    // Seed Placeholder
    await db.gameDao.updateCharacterStats(
      CharacterCompanion(
        name: const Value('Traveler'),
        heroClass: const Value('Fighter'),
        level: const Value(1),
        currentHp: const Value(10),
        maxHp: const Value(10),
        gold: const Value(0),
        location: const Value('Unknown'),
        worldId: Value(worldId),
      ),
    );

    // Provide dependencies
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: CharacterCreationScreen(worldId: worldId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I enter "Sir Testalot" as the name
    await tester.enterText(find.byType(TextField).first, 'Sir Testalot');
    await tester.pumpAndSettle();

    // AND I select "Fighter" class (Default) and "Human" species (Default)
    // (We verify defaults are present to confirm "selection")
    expect(find.text('Fighter'), findsWidgets);
    expect(find.text('Human'), findsWidgets);

    // AND I tap "Create Character"
    // Requires scrolling to bottom
    final createButton = find.text('Create Character');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);

    // Pump navigation
    await tester.pumpAndSettle();

    // THEN the character should be saved to the database
    final char = await db.gameDao.getCharacter(worldId);
    expect(char, isNotNull);
    expect(char!.name, 'Sir Testalot');
    expect(char.heroClass, 'Fighter');
    expect(char.species, 'Human');

    // AND I should be navigated to the Game Screen
    expect(find.byType(GameScreen), findsOneWidget);

    await db.close();
  });
}
