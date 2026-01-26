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

void main() {
  testWidgets('BDD Scenario: Homebrew Content Flow',
      (WidgetTester tester) async {
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
        heroClass: const Value('Fighter'),
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
    await tester.drag(find.text('Cyborg'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // THEN "Cyborg" should be gone from the list
    expect(find.text('Cyborg'), findsNothing);

    // AND "Cyborg" deleted message should be shown
    expect(find.text('Cyborg deleted'), findsOneWidget);

    // Re-create it for the next part (Character Creation) or skip?
    // The test continues to Character Creation expecting "Cyborg".
    // If we delete it, we can't select it.
    // So we should re-create it or just remove the deletion part from THIS flow
    // and make a separate "Manage Homebrew" test vs "Use Homebrew" test.
    // OR we delete it and verify, then re-add it.
    // Let's re-add it quickly.

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Cyborg');
    await tester.enterText(find.byType(TextField).at(1), 'Re-added');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Cyborg'), findsOneWidget);

    // AND I navigate to "Character Creation" (Simulated by pumping widget directly)
    // We skip manual navigation from MainMenu as it typically goes to GameScreen for existing worlds.
    // We assume the user creates a new world or somehow enters creation mode.
    // Clear the tree to ensure HomebrewManagerScreen is disposed
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
    await tester.pumpAndSettle(); // Loads placeholder

    // THEN "Cyborg" should be available in the Species dropdown
    // Open Species dropdown (default is Human)
    // DEBUG: Dump Widgets before failing tap
    // Select Cyborg
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, 'Human'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cyborg').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Character Name'), 'RoboCop');

    final createBtn = find.text('Create Character');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Verify DB
    final char = await db.gameDao.getCharacter(worldId);
    expect(char!.species, 'Cyborg');

    await db.close();
  });
}
