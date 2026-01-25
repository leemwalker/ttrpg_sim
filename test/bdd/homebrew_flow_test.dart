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
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Cyborg');
    await tester.enterText(find.widgetWithText(TextField, 'Description'),
        'Part man, part machine');

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
