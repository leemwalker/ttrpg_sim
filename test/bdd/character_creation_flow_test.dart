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
import 'package:ttrpg_sim/features/creation/steps/step_species.dart';
import 'package:ttrpg_sim/features/creation/steps/step_origin.dart';

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
    final humanOption =
        find.byKey(const ValueKey('species_option_Human')).first;
    await tester.scrollUntilVisible(humanOption, 500,
        scrollable: find.descendant(
            of: find.byType(StepSpecies), matching: find.byType(Scrollable)));
    await tester.tap(humanOption);
    await tester.pumpAndSettle();

    final nextBtn1 = find.byKey(const ValueKey('step_0_next')).first;
    await tester.ensureVisible(nextBtn1);
    await tester.tap(nextBtn1);
    await tester.pumpAndSettle();

    // Step 2: Origin. Select 'Refugee'.
    final refugeeOption =
        find.byKey(const ValueKey('origin_option_Refugee')).first;
    await tester.scrollUntilVisible(refugeeOption, 500,
        scrollable: find.descendant(
            of: find.byType(StepOrigin), matching: find.byType(Scrollable)));
    await tester.tap(refugeeOption);
    await tester.pumpAndSettle();

    final nextBtn2 = find.byKey(const ValueKey('step_1_next')).first;
    await tester.ensureVisible(nextBtn2);
    await tester.tap(nextBtn2);
    await tester.pumpAndSettle();

    // Step 3: Traits. Next.
    final nextBtn3 = find.byKey(const ValueKey('step_2_next'));
    await tester.ensureVisible(nextBtn3);
    await tester.tap(nextBtn3);
    await tester.pumpAndSettle();

    // Step 4: Attributes. Next.
    final nextBtn4 = find.byKey(const ValueKey('step_3_next'));
    await tester.ensureVisible(nextBtn4);
    await tester.tap(nextBtn4);
    await tester.pumpAndSettle();

    // Step 5: Skills (Finish).
    // Verify Finish button
    final finishBtn = find.byKey(const ValueKey('step_4_next'));
    await tester.ensureVisible(finishBtn);
    await tester.tap(finishBtn);

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
