import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/menu/main_menu_screen.dart';
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'shared_test_utils.dart';

void main() {
  testWidgets('MainMenuScreen creates world with Custom genre',
      (WidgetTester tester) async {
    // Setup Rules
    // Setup Rules
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

    // Setup In-Memory DB
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: MainMenuScreen()),
      ),
    );

    // Open Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify Chips exist
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // Select Custom
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // Enter details
    // Name is 1st (index 0), Tone is 2nd (index 1), Description is 3rd (index 2)
    // Tone is in the middle. Description is Multi-line.
    // Order in CreateWorldScreen: Name, Tone, Description
    await tester.enterText(find.byType(TextField).at(0), 'New World');
    await tester.enterText(find.byType(TextField).at(1), 'Steampunk'); // Tone
    await tester.enterText(
        find.byType(TextField).at(2), 'Gears and Steam'); // Description

    // Create
    await tester.tap(find.text('Create World'));
    await tester.pumpAndSettle();

    // Verify DB
    final worlds = await db.gameDao.getAllWorlds();
    expect(worlds.length, 1);
    expect(worlds.first.name, 'New World');
    expect(worlds.first.genre, 'Custom'); // Since we selected Custom chip

    await db.close();
  });
}
