import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

// ... imports

// Mock Helper
// ... imports
import '../shared_test_utils.dart'; // Import shared mocks

void main() {
  testWidgets('CharacterCreationScreen Widget Test',
      (WidgetTester tester) async {
    // Increase surface size to avoid layout overflow
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 0. Setup Rules
    final mockLoader = MockRuleDataLoader();
    mockLoader.setupDefaultRules();

    await ModularRulesController().loadRules(loader: mockLoader);

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
      genres: const Value('["Fantasy"]'),
    ));
    await db.gameDao.updateCharacterStats(
      const CharacterCompanion(
        name: Value('Traveler'), // Placeholder name
        level: Value(1),
        currentHp: Value(10),
        maxHp: Value(10),
        gold: Value(0),
        location: Value('Unknown'),
        worldId: Value(worldId),
        species: Value('Human'),
        origin: Value('Unknown'),
        attributes: Value('{}'),
        skills: Value('{}'),
        traits: Value('[]'),
        feats: Value('[]'),
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
    // Name field should be empty because 'Traveler' is cleared logic?
    // Actually Logic says: if (existing.name != 'Traveler' ...) _nameController.text = existing.name;
    // So 'Traveler' should NOT be in the text field.
    expect(find.text('Traveler'), findsNothing);

    // Default Species 'Human'
    // It's a ListView now, so we look for the Text 'Human' which is in a ListTile
    expect(find.text('Human'), findsOneWidget);
    // Verify it is selected? The selected card has a checkmark.
    // We can find the checkmark near 'Human'.
    // Or just check that 'Elf' is also there.
    expect(find.text('Elf'), findsOneWidget);

    // 6. Test Species Change
    // Tap 'Elf'
    await tester.tap(find.text('Elf'));
    await tester.pumpAndSettle();

    // Verify 'Elf' is selected (Visual check is hard, but state changes)
    // We can proceed to next step to verify flow.

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Should be on Origin Step
    // Verify Origin list appears (e.g. 'Refugee' from defaults)
    expect(find.text('Refugee'), findsOneWidget);

    // Cleanup
    await db.close();
  });
}
