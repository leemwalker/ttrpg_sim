import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/features/creation/widgets/point_buy_widget.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

void main() {
  testWidgets('CharacterCreationScreen Widget Test',
      (WidgetTester tester) async {
    // 1. Setup In-Memory Database
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);
    const worldId = 1;

    // 2. Seed Database with Placeholder Character (Required by Screen)
    await db.gameDao.createWorld(WorldsCompanion.insert(
      id: const Value(1),
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'), // Placeholder name
        heroClass: Value('Fighter'),
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(worldId),
      ),
    );

    // 3. Pump Widget
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: CharacterCreationScreen(worldId: worldId),
        ),
      ),
    );

    // 4. Wait for Async Load
    await tester.pumpAndSettle();

    // 5. Verify Initial State
    // Name field should be empty because 'Traveler' is cleared
    expect(find.text('Traveler'), findsNothing);
    // Default Class 'Fighter'
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Fighter'),
        findsOneWidget);
    // Default Species 'Human'
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Human'),
        findsOneWidget);

    // 6. Test Species Dropdown Change
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, 'Human'));
    await tester.pumpAndSettle();

    // Select 'Elf'
    await tester.tap(find.text('Elf').last);
    await tester.pumpAndSettle();

    // Verify UI updated
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Elf'),
        findsOneWidget);

    // 7. Test Point Buy Widget interactions
    // Find PointBuyWidget
    expect(find.byType(PointBuyWidget), findsOneWidget);

    // Find the '+' button for Strength (Strength is first item)
    // We can look for the row containing 'Strength'
    final strengthRow = find
        .ancestor(
          of: find.text('Strength'),
          matching: find.byType(Row),
        )
        .first;

    // Within that row, find the add button
    final addButton = find.descendant(
      of: strengthRow,
      matching: find.byIcon(Icons.add_circle_outline),
    );

    // Current Score is 8. Points: 27.
    expect(find.text('Points: 27'), findsOneWidget);

    // Tap '+'
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    // Verify Score is 9 and Points Decreased (Cost 1)
    expect(find.text('Points: 26'), findsOneWidget);
    // We can also verify the text '9' appears near Strength, but finding strict descendant might be tricky with multiple '9's potentially.
    // Simpler to rely on points remaining update which confirms logic ran.

    // Cleanup
    await db.close();
  });
}
