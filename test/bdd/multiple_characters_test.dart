import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/campaign/character_selection_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import '../shared_test_utils.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

void main() {
  testWidgets('BDD Scenario: Multiple Characters in a Single World',
      (WidgetTester tester) async {
    // Setup Rules
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

    // 2. Create World
    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'Shared World',
      genre: 'Fantasy',
      description: 'A world of many heroes',
    ));

    // 3. Create First Character (Hero A) manually in DB (simulating creation)
    final charAId = await database.into(database.character).insert(
        CharacterCompanion.insert(
            name: 'Hero A',
            species: const drift.Value('Human'),
            level: 1,
            currentHp: 10,
            maxHp: 10,
            gold: 100,
            location: 'Town Square',
            worldId: drift.Value(worldId),
            origin: const drift.Value('Soldier')));

    // Add unique history for A
    await dao.insertMessage('system', 'Hero A Story Start', worldId, charAId);

    // 4. Create Second Character (Hero B) manually in DB
    final charBId = await database.into(database.character).insert(
        CharacterCompanion.insert(
            name: 'Hero B',
            species: const drift.Value('Elf'),
            level: 1,
            currentHp: 8,
            maxHp: 8,
            gold: 50,
            location: 'Forest Edge',
            worldId: drift.Value(worldId),
            origin: const drift.Value('Wanderer')));

    // Add unique history for B
    await dao.insertMessage('system', 'Hero B Story Start', worldId, charBId);

    // 5. Load Character Selection Screen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: CharacterSelectionScreen(worldId: worldId)),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both characters are listed
    expect(find.text('Hero A'), findsOneWidget);
    expect(find.text('Hero B'), findsOneWidget);

    // 6. Select Hero A and Verify Context
    await tester.tap(find.text('Hero A'));
    await tester.pumpAndSettle();

    // Verify we are on GameScreen for Hero A
    expect(find.byType(GameScreen), findsOneWidget);
    // You might want to check the app bar or some verified text if accessible
    // But let's verify DB state isolation by checking messages via DAO
    final messagesA = await dao.getRecentMessages(charAId, 10);
    expect(messagesA.length, 1);
    expect(messagesA.first.content, 'Hero A Story Start');

    // 7. Go back (Pop)
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // 8. Select Hero B and Verify Context
    await tester.tap(find.text('Hero B'));
    await tester.pumpAndSettle();

    // Verify we are on GameScreen for Hero B
    expect(find.byType(GameScreen), findsOneWidget);

    final messagesB = await dao.getRecentMessages(charBId, 10);
    expect(messagesB.length, 1);
    expect(messagesB.first.content, 'Hero B Story Start');

    // Verify independent stats
    final charA = await dao.getCharacterById(charAId);
    final charB = await dao.getCharacterById(charBId);

    expect(charA?.gold, 100);
    expect(charB?.gold, 50);
    expect(charA?.species, 'Human');
    expect(charB?.species, 'Elf');
  });
}
