import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/menu/main_menu_screen.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('MainMenuScreen creates world with Custom genre',
      (WidgetTester tester) async {
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
    await tester.enterText(
        find.widgetWithText(TextField, 'World Name'), 'New World');
    await tester.enterText(
        find.widgetWithText(TextField, 'Enter Custom Genre'), 'Steampunk');
    await tester.enterText(
        find.widgetWithText(TextField, 'Concept/Description'),
        'Gears and Steam');

    // Create
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Verify DB
    final worlds = await db.gameDao.getAllWorlds();
    expect(worlds.length, 1);
    expect(worlds.first.name, 'New World');
    expect(worlds.first.genre, 'Steampunk');

    await db.close();
  });
}
