import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/features/menu/main_menu_screen.dart';
import 'package:ttrpg_sim/features/settings/homebrew_manager_screen.dart';
import 'package:ttrpg_sim/features/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../shared_test_utils.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  testWidgets('BDD Scenario: Homebrew Content Flow',
      (WidgetTester tester) async {
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);
    // SETUP
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // Seed a world so we can go to Character Creation later
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'A realm for testing',
    ));
    // Seed placeholder for that world
    await db.gameDao.updateCharacterStats(
      CharacterCompanion(
        name: const Value('Traveler'),
        level: const Value(1),
        currentHp: const Value(10),
        maxHp: const Value(10),
        gold: const Value(0),
        location: const Value('Unknown'),
        worldId: Value(worldId),
      ),
    );

    // GIVEN I am in the App (MainMenu)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: MainMenuScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I navigate to "Settings"
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // AND I navigate to "Manage Custom Content"
    await tester.tap(find.text('Manage Custom Content'));
    await tester.pumpAndSettle();
    expect(find.byType(HomebrewManagerScreen), findsOneWidget);

    // AND I create a new Species named "Cyborg"
    // 1. Ensure "Species" tab is selected (default)
    expect(find.text('Species'), findsOneWidget);

    // 2. Tap Add FAB
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // 3. Fill Dialog
    // Find Name field (first TextField)
    await tester.enterText(find.byType(TextField).at(0), 'Cyborg');
    // Find Description field (second TextField)
    await tester.enterText(
        find.byType(TextField).at(1), 'Part man, part machine');

    // 4. Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verification: Check DB directly
    final traits = await db.gameDao.getCustomTraitsByType('Species');
    print("DEBUG: DB Species Count: ${traits.length}");
    if (traits.isNotEmpty) {
      print(
          "DEBUG: Created Trait: ${traits.first.name} (${traits.first.type})");
    }

    // Explicit pump to handle FutureBuilder timing
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // DEBUG: Dump Widgets
    print("=== HOMEBREW UI DUMP ===");
    find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .forEach(print);
    print("========================");

    // THEN "Cyborg" should be in the list
    expect(find.text('Cyborg'), findsOneWidget);

    // AND I delete "Cyborg" (Swipe to dismiss)
    await tester.drag(find.text('Cyborg'), const Offset(-1000, 0));
    await tester.pumpAndSettle();

    // THEN "Cyborg" should be gone from the list
    expect(find.text('Cyborg'), findsNothing);

    // AND "Cyborg" deleted message should be shown
    expect(find.text('Cyborg deleted'), findsOneWidget);

    // Re-create it for the next part (Character Creation)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Cyborg');
    await tester.enterText(find.byType(TextField).at(1), 'Re-added');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Cyborg'), findsOneWidget);

    // AND I navigate to "Character Creation"
    await tester.pumpWidget(const SizedBox());

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

    // THEN "Cyborg" should be available in the Species Step (Step 1)
    // Verify it exists
    expect(find.text('Cyborg'), findsOneWidget);

    // Tap it
    await tester.tap(find.text('Cyborg'));
    await tester.pumpAndSettle();

    // Verify selection (Checkmark)
    // Finding ListTile with text Cyborg, then finding Icon inside it
    final cyborgTile = find.widgetWithText(ListTile, 'Cyborg');
    expect(
        find.descendant(
            of: cyborgTile, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);

    // Next (to Origin)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Origin Step (Select something default or first?)
    // Default might be selected if testing creation logic usually has defaults.
    // If we need to select:
    await tester.tap(find.text('Refugee')); // Assuming default
    await tester.pumpAndSettle();

    // Next (to Traits)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Next (to Attributes)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Next (to Skills)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Fill Name (It's on top, accessible always or in a step?)
    // In CharacterCreationScreen (Step 258):
    // standard TextField inside Column, above Expanded Stepper.
    // So Name is always visible.
    await tester.enterText(
        find.widgetWithText(TextField, 'Character Name'), 'RoboCop');

    // Finish
    final createBtn = find.text('Finish');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Verify DB
    final char = await db.gameDao.getCharacter(worldId);
    expect(char!.species, 'Cyborg');

    await db.close();
  });
}
