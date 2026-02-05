import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/imagin8/imagin8_creation_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'mock_gemini_service.dart';

void main() {
  testWidgets('BDD Scenario: Imagin8 Character Creation and Gameplay',
      (WidgetTester tester) async {
    // 0. Setup Large Surface
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Setup
    final db = AppDatabase(NativeDatabase.memory());
    final dao = db.gameDao;

    // Seed some cards for testing
    await db.batch((batch) {
      batch.insertAll(db.imagin8Cards, [
        Imagin8CardsCompanion.insert(
            id: const drift.Value(1),
            name: 'Human',
            type: 'Origin',
            description: 'Desc',
            deck: 'Core'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(2),
            name: 'Sword',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(3),
            name: 'Shield',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(4),
            name: 'Magic',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(5),
            name: 'Fire',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(10),
            name: 'Heal',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(11),
            name: 'Buff',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(12),
            name: 'Zap',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(13),
            name: 'Run',
            type: 'Ability',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(6),
            name: 'Curse',
            type: 'Drawback',
            description: 'Desc',
            deck: 'Core'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(7),
            name: 'Weakness',
            type: 'Drawback',
            description: 'Desc',
            deck: 'Core'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(8),
            name: 'Fear',
            type: 'Drawback',
            description: 'Desc',
            deck: 'Core'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(9),
            name: 'Debt',
            type: 'Drawback',
            description: 'Desc',
            deck: 'Core'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(20),
            name: 'Trait 1',
            type: 'Trait',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(21),
            name: 'Trait 2',
            type: 'Trait',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(22),
            name: 'Trait 3',
            type: 'Trait',
            description: 'Desc',
            deck: 'Fantasy'),
        Imagin8CardsCompanion.insert(
            id: const drift.Value(23),
            name: 'Trait 4',
            type: 'Trait',
            description: 'Desc',
            deck: 'Fantasy'),
      ]);
    });

    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'Imagin8 World',
      genre: 'Fantasy',
      description: 'Test',
      system: const drift.Value('imagin8'),
      selectedDecks: const drift.Value('["Fantasy", "Core"]'),
    ));

    // 2. Character Creation
    final mockGemini = MockGeminiService();
    await tester.pumpWidget(ProviderScope(
      key: const Key('creation'),
      overrides: [
        databaseProvider.overrideWithValue(db),
        geminiServiceProvider.overrideWithValue(mockGemini),
      ],
      child: MaterialApp(home: Imagin8CreationScreen(worldId: worldId)),
    ));
    await tester.pumpAndSettle();

    // Select Origin
    await tester.tap(find.text('Human'));
    await tester.pumpAndSettle();

    // Select 4 Abilities and 4 Drawbacks (excluding Origin)
    final cardsToTap = [
      'Sword',
      'Shield',
      'Magic',
      'Fire',
      'Curse',
      'Weakness',
      'Fear',
      'Debt',
      'Trait 1',
      'Trait 2',
      'Trait 3',
      'Trait 4', // 4 Abilities, 4 Traits (8 Normal), 4 Drawbacks. Balanced.
    ];
    // Helper to scroll and tap
    Future<void> scrollAndTap(String text) async {
      final finder = find.text(text);
      final scrollable = find.descendant(
          of: find.byKey(const Key('handGrid')),
          matching: find.byType(Scrollable));

      await tester.scrollUntilVisible(finder, 200.0, scrollable: scrollable);
      await tester.tap(finder);
      await tester.pump();
    }

    for (final cardName in cardsToTap) {
      await scrollAndTap(cardName);
    }
    await tester.pumpAndSettle();

    // Go to Finalize
    final nextBtn = find.text('Next');
    await tester.ensureVisible(nextBtn);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Enter Name and Create
    await tester.enterText(find.byType(TextField).first, 'Imagin8 Hero');
    final createBtn = find.text('Create Character');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Verify character exists

    final char = await dao.getCharacter(worldId);
    expect(char, isNotNull);
    expect(char!.name, 'Imagin8 Hero');
    final hand = jsonDecode(char.hand!) as List;
    expect(hand.length, 12);

    // 3. Gameplay Loop
    await tester.pumpWidget(ProviderScope(
      key: const Key('gameplay'),
      overrides: [
        databaseProvider.overrideWithValue(db),
        geminiServiceProvider.overrideWithValue(mockGemini),
      ],
      child:
          MaterialApp(home: GameScreen(worldId: worldId, characterId: char.id)),
    ));
    await tester.pumpAndSettle();

    // Verify Imagin8 UI triggers
    // We open the Drawer which contains the Imagin8Sheet
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Wait for cards to load from DB
    for (int i = 0; i < 5 && tester.any(find.text('Loading cards...')); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Hand (12)'), findsWidgets);
    expect(find.text('Sword', skipOffstage: false), findsWidgets);

    // Play Card: Tap the card name to open dialog
    await tester.ensureVisible(find.text('Sword', skipOffstage: false));
    await tester.tap(find.text('Sword'));
    await tester.pumpAndSettle();

    // Tap "Play Card" in dialog
    await tester.tap(find.text('Play Card'));
    await tester.pumpAndSettle();

    // Verify Hand update in DB
    final charAfterPlay = await dao.getCharacterById(char.id);
    final handAfterPlay = jsonDecode(charAfterPlay!.hand!) as List;
    expect(handAfterPlay.length, 11);

    // Close Drawer
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Roll d8
    // In Imagin8Sheet it has a roll button. Drag drawer open again.
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Roll d8'));
    await tester.pumpAndSettle();

    // Close Drawer to see message
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Risk Roll (d8)'), findsWidgets);

    expect(find.textContaining('Risk Roll (d8)'), findsWidgets);

    // Verify Export Campaign Button Exists
    await tester.dragFrom(
        tester.getTopLeft(find.byType(MaterialApp)), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Export Campaign'), findsOneWidget);

    await tester.tapAt(const Offset(400, 300)); // Close drawer
    await tester.pumpAndSettle();

    await db.close();
  });
}
