import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import '../shared_test_utils.dart';

void main() {
  testWidgets('BDD Scenario: Change Mind (Cancel Creation)',
      (WidgetTester tester) async {
    // SETUP
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // We need a world to enter creation
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(CharacterCompanion(
      worldId: Value(worldId),
      name: const Value('Draft'),
      level: const Value(1),
      currentHp: const Value(10),
      maxHp: const Value(10),
      gold: const Value(0),
      location: const Value('Init'),
    ));

    // GIVEN I am on Character Creation
    // We wrap it in a Navigator to allow "Pop" logic
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

    expect(find.text('Select Species'), findsWidgets);

    // WHEN I press the "Back" button (AppBar back arrow)
    // Implicitly provided by Scaffold AppBar if canPop, OR we force a pop if it's the root.
    // If it is the home, there is no back button unless pushed.
    // To test navigation, we should push it.

    // Re-pump with a stack
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CharacterCreationScreen(worldId: worldId)));
                },
                child: const Text('Go to Creation'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go to Creation'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterCreationScreen), findsOneWidget);

    // ACT: Tap Back Button
    final backButton = find.byIcon(Icons.arrow_back);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // THEN I should be returned (Creation Screen is gone)
    expect(find.byType(CharacterCreationScreen), findsNothing);
    expect(find.text('Go to Creation'), findsOneWidget);

    await db.close();
  });
}
