import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../shared_test_utils.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'mock_gemini_service.dart';

void main() {
  testWidgets('BDD Scenario: Create Character', (WidgetTester tester) async {
    // GIVEN I am on the Character Creation screen for a new world
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    final mockGemini = MockGeminiService();
    const worldId = 1;

    // Seed World
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
    ));
    // Seed Placeholder
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'),
        species: Value('Human'), // Default
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(worldId),
      ),
    );

    // Provide dependencies
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(
          home: CharacterCreationScreen(worldId: worldId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I enter "Sir Testalot" as the name
    await tester.enterText(find.byType(TextField).first, 'Sir Testalot');
    await tester.pumpAndSettle();

    // AND I select "Human" species (Default) - Class selection removed
    // (We verify defaults are present to confirm "selection")
    expect(find.text('Human'), findsWidgets);

    // Navigate Stepper
    // Step 1: Species. Select 'Human'.
    await tester.tap(find.text('Human'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: Origin. Select 'Refugee'.
    await tester.tap(find.text('Refugee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3: Traits. Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4: Attributes. Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 5: Skills. Finish.
    final createButton = find.text('Finish');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);

    // Pump navigation
    await tester.pumpAndSettle();

    // Verify DB
    final char = await db.gameDao.getCharacter(worldId);
    expect(char, isNotNull);
    expect(char!.name, 'Sir Testalot');
    expect(char.species, 'Human');

    await db.close();
  });
}
