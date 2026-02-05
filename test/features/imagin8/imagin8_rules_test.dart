import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/imagin8/imagin8_creation_screen.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ttrpg_sim/core/services/ai_prompt_builder.dart';

void main() {
  late AppDatabase db;
  late GameDao dao;

  setUp(() {
    final executor = NativeDatabase.memory();
    db = AppDatabase(executor);
    dao = db.gameDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('Imagin8 Rules Integration Tests', () {
    testWidgets('Scenario 1: Law of Balance (Creation)',
        (WidgetTester tester) async {
      // Increase screen size to avoid layout overflow/hit test issues
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // GIVEN: Seeded Cards
      // mechanic is Nullable (Value), description/deck are Required (String)
      await db.batch((batch) {
        batch.insertAll(
            db.imagin8Cards,
            [
              Imagin8CardsCompanion.insert(
                  id: drift.Value(1),
                  name: 'Bio-EMP',
                  type: 'Ability',
                  description: 'Zap',
                  mechanic: drift.Value('Zap'),
                  deck: 'Cyber'),
              Imagin8CardsCompanion.insert(
                  id: drift.Value(2),
                  name: 'Cyberpsychosis',
                  type: 'Drawback',
                  description: 'Crazy',
                  mechanic: drift.Value('Crazy'),
                  deck: 'Cyber'),
              Imagin8CardsCompanion.insert(
                  id: drift.Value(3),
                  name: 'Human',
                  type: 'Origin',
                  description: 'Basic',
                  mechanic: drift.Value('None'),
                  deck: 'Core'),
            ],
            mode: drift.InsertMode.insertOrReplace);
      });

      await dao.createWorld(WorldsCompanion.insert(
          name: 'Neo Tokyo',
          genre: 'Cyberpunk',
          description: 'A neon-soaked metropolis.',
          system: drift.Value('Imagin8'), // Optional/Nullable
          selectedDecks:
              drift.Value(jsonEncode(['Cyber', 'Core'])) // Optional/Nullable
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: Imagin8CreationScreen(worldId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      // WHEN: Select Origin (Human) -> Go to Hand
      await tester.tap(
          find.text('Human')); // Select Origin (Step 0) - This auto-advances
      // await tester.tap(find.text('Next')); // REMOVED: Redundant, skips Hand step
      await tester.pumpAndSettle();

      // WHEN: Select 1 Ability (Bio-EMP) and 0 Drawbacks
      await tester.tap(find.text('Bio-EMP'));
      await tester.pumpAndSettle();

      // Navigate to Finalize
      final nextButton = find.text('Next');
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // THEN: "Create Character" button should be disabled/show error verify logic
      // Ensure we are on the Finalize step
      expect(find.byType(TextField), findsWidgets,
          reason: "Should be on Finalize step with TextFields");

      await tester.enterText(find.byType(TextField).first, "Akira");

      // Verify Error Message is present
      expect(find.textContaining('Must select exactly 8 normal cards'),
          findsOneWidget);

      // Verify Button is disabled (optional, but good practice)
      // Note: FilledButton onPressed: null doesn't change key/text, just visual state.
      // We can check if tapping it does nothing (i.e. we are still on the same screen).
      await tester.tap(find.text('Create Character'));
      await tester.pump();

      // Expect to still be on the page (e.g. "Finalize" text or error text still visible)
      expect(find.text('Finalize'), findsOneWidget);

      // We expect no navigation (remain on screen) or error.
      // Since validation is currently missing, this part of the test might behave unexpectedly (i.e. success).
      // We'll leave it as an interaction test for now.
    });

    test('Scenario 2: The Cycle of Action (Gameplay Loop)', () async {
      // GIVEN: Active Character with Card in Hand
      await dao.createWorld(WorldsCompanion.insert(
          id: drift.Value(1), // Force ID 1
          name: 'Neo Tokyo',
          genre: 'Cyberpunk',
          description: 'Tests',
          system: drift.Value('Imagin8'),
          selectedDecks: drift.Value(jsonEncode(['Cyber', 'Core']))));

      final charId = await dao.updateCharacterStats(CharacterCompanion.insert(
        name: 'Solo',
        worldId: drift.Value(1),
        hand: drift.Value(jsonEncode([101])), // 101: Plasma Gun
        discardPile: drift.Value(jsonEncode([])),
        level: 1, currentHp: 10, maxHp: 10, gold: 0,
        species: drift.Value('Human'), origin: drift.Value('Street'),
        location: 'Void', // Wrapped Values for default columns
        attributes: drift.Value('{}'),
        skills: drift.Value('{}'),
        equipment: drift.Value('{}'),
        traits: drift.Value('[]'),
        feats: drift.Value('[]'),
        spells: drift.Value('[]'),
        xp: drift.Value(0),
        currentMana: drift.Value(0),
        maxMana: drift.Value(0),
        armorClass: drift.Value(10),
      ));

      await db.batch((batch) {
        batch.insertAll(
            db.imagin8Cards,
            [
              Imagin8CardsCompanion.insert(
                  id: drift.Value(101),
                  name: 'Plasma Gun',
                  type: 'Item',
                  description: 'Boom',
                  mechanic: drift.Value('Shoot'),
                  deck: 'Cyber'),
            ],
            mode: drift.InsertMode.insertOrReplace);
      });

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(gameControllerProvider(1, charId).notifier);
      await container.read(gameControllerProvider(1, charId).future);

      // Play Card
      await controller.playImagin8Card(101);

      // Verify DB State
      final charAfterPlay = await dao.getCharacterById(charId);
      final handAfter = jsonDecode(charAfterPlay!.hand!);
      final discardAfter = jsonDecode(charAfterPlay.discardPile!);

      expect(handAfter, isEmpty, reason: "Hand should be empty after play");
      expect(discardAfter, contains(101),
          reason: "Discard should contain card");

      // Recover All
      await controller.recoverAllImagin8Cards();

      final charAfterRecover = await dao.getCharacterById(charId);
      final handRecovered = jsonDecode(charAfterRecover!.hand!);
      expect(handRecovered, contains(101),
          reason: "Card should be back in hand");
    });

    test('Scenario 3: The Oracle\'s Vision (AI Prompt)', () async {
      // Unit test AIPromptBuilder directly
      final hand = [
        Imagin8Card(
            id: 201,
            name: 'Mono-Katana',
            type: 'Item',
            description: 'Blade sharpened to a single molecule.',
            mechanic: 'Cut',
            deck: 'Cyber')
      ];

      final prompt = AIPromptBuilder.buildContextPrompt(
          "I attack!",
          CharacterData(
              id: 1,
              name: 'Seer',
              worldId: 1,
              level: 1,
              currentHp: 10,
              maxHp: 10,
              gold: 0,
              hand: jsonEncode([201]),
              discardPile: jsonEncode([]),
              equipment: '{}',
              attributes: '{}',
              skills: '{}',
              traits: '[]',
              feats: '[]',
              species: 'Human',
              origin: 'Unknown',
              location: 'Void',
              // Default stats
              strength: 10,
              dexterity: 10,
              constitution: 10,
              intelligence: 10,
              wisdom: 10,
              charisma: 10,
              armorClass: 10,
              currentMana: 0,
              maxMana: 0,
              xp: 0,
              spells: '[]', // spells is String
              inventory: '[]'),
          [], // Inventory is 3rd Positional
          hand: hand,
          discard: [],
          worldKnowledge: "None");

      expect(prompt, contains('Mono-Katana'),
          reason: "Prompt should mention card name");
      expect(prompt, contains('Item'),
          reason: "Prompt should mention card type");
      expect(prompt, contains('Blade sharpened'),
          reason: "Prompt should include description");
    });
  });
}
