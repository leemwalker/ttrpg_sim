import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/campaign/character_selection_screen.dart';
import '../shared_test_utils.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

void main() {
  testWidgets('Character Deletion (Partial Cascade)',
      (WidgetTester tester) async {
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

    // 1. Setup Database
    final database = AppDatabase(NativeDatabase.memory());
    final dao = GameDao(database);
    addTearDown(() async {
      await database.close();
    });

    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'Persistent World',
      genre: 'Sci-Fi',
      description: 'World should survive',
    ));

    final charId = await database.into(database.character).insert(
        CharacterCompanion.insert(
            name: 'Sacrifice',
            species: const drift.Value('Human'),
            level: 1,
            currentHp: 10,
            maxHp: 10,
            gold: 0,
            location: 'Barracks',
            worldId: drift.Value(worldId),
            origin: const drift.Value('Unknown')));

    await dao.addItem(charId, "Rifle");

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: CharacterSelectionScreen(worldId: worldId)),
      ),
    );
    await tester.pumpAndSettle();

    // Verify presence
    expect(find.text('Sacrifice'), findsOneWidget);

    // Delete
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify Character Gone
    expect(find.text('Sacrifice'), findsNothing);

    // Verify World Persistence
    final worlds = await dao.getAllWorlds();
    expect(worlds.isNotEmpty, true);
    expect(worlds.first.name, 'Persistent World');

    // Verify Inventory Gone
    final items = await dao.getInventory();
    expect(items.isEmpty, true);
  });

  testWidgets('Empty World Character Creation (Bug Fix)',
      (WidgetTester tester) async {
    // Increase screen size for stepper
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final mockLoader = MockRuleDataLoader();
    mockLoader.setTestScreenSize(tester);
    mockLoader.setupDefaultRules();
    await ModularRulesController().loadRules(loader: mockLoader);

    // 1. Setup Database
    final database = AppDatabase(NativeDatabase.memory());
    final dao = GameDao(database);
    addTearDown(() async {
      await database.close();
    });

    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'Empty World',
      genre: 'Void',
      description: 'No characters yet',
    ));

    // 2. Pump Character Selection Screen (will show "No characters")
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: CharacterSelectionScreen(worldId: worldId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No characters found in this world.'), findsOneWidget);

    // 3. Tap Create -> Should navigate to Creation Screen without crashing
    await tester.tap(find.text('Create New Character'));
    await tester.pumpAndSettle();

    // Verify we are on creation screen
    expect(find.text('Select Species'), findsWidgets);

    // 4. Fill form (Name is first TextField)
    await tester.enterText(find.byType(TextField).first, 'First Born');
    await tester.pumpAndSettle();

    // Tap Finish (might sort of skip steps validation but Name is filled.
    // Screen might require Species/Origin selection.
    // Default selection logic in StepSpecies?
    // Let's tap 'Next' until 'Finish' is visible?
    // Or just "Finish" if available? Stepper usually shows Next until last.
    // Tests: The BDD test logic assumed simple form. Now it's a stepper.
    // We should step through.
    // Step 1: Species. Select 'Human'.
    final humanOption =
        find.byKey(const ValueKey('species_option_Human')).first;
    // Use the scrollable inside the PageView
    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(humanOption, 500, scrollable: scrollable);
    await tester.tap(humanOption);
    await tester.pumpAndSettle();

    // Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: Origin. Select 'Refugee'.
    final refugeeOption =
        find.byKey(const ValueKey('origin_option_Refugee')).first;
    await tester.scrollUntilVisible(refugeeOption, 500, scrollable: scrollable);
    await tester.tap(refugeeOption);
    await tester.pumpAndSettle();

    // Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3: Traits. Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4: Attributes. Next.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 5: Skills (Last). Finish.
    final finishBtn = find.text('Finish');
    await tester.ensureVisible(finishBtn);
    expect(finishBtn, findsOneWidget);
    await tester.tap(finishBtn);
    await tester.pumpAndSettle();

    // 5. Verify Character Created and Game Screen Loaded
    expect(find.text('First Born'), findsOneWidget);

    final chars = await dao.getCharactersForWorld(worldId);
    expect(chars.length, 1);
    expect(chars.first.name, 'First Born');
  });
}
