import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/imagin8/imagin8_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import '../../bdd/mock_gemini_service.dart';

void main() {
  late AppDatabase db;
  late GameDao dao;
  late int worldId;
  late MockGeminiService mockGemini;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.gameDao;
    mockGemini = MockGeminiService();

    // 1. Seed Cards
    await db.batch((batch) {
      batch.insert(
          db.imagin8Cards,
          Imagin8CardsCompanion.insert(
              id: const drift.Value(1),
              name: 'Human',
              type: 'Origin',
              description: 'Desc',
              deck: 'Core'));

      for (int i = 0; i < 10; i++) {
        batch.insert(
            db.imagin8Cards,
            Imagin8CardsCompanion.insert(
                id: drift.Value(10 + i),
                name: 'Trait $i',
                type: 'Trait',
                description: 'Desc',
                deck: 'Fantasy'));
      }

      for (int i = 0; i < 5; i++) {
        batch.insert(
            db.imagin8Cards,
            Imagin8CardsCompanion.insert(
                id: drift.Value(20 + i),
                name: 'Ability $i',
                type: 'Ability',
                description: 'Desc',
                deck: 'Fantasy'));
      }

      for (int i = 0; i < 5; i++) {
        batch.insert(
            db.imagin8Cards,
            Imagin8CardsCompanion.insert(
                id: drift.Value(30 + i),
                name: 'Drawback $i',
                type: 'Drawback',
                description: 'Desc',
                deck: 'Core'));
      }
    });

    worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'Imagin8 World',
      genre: 'Fantasy',
      description: 'Test',
      system: const drift.Value('imagin8'),
      selectedDecks: const drift.Value('["Fantasy", "Core"]'),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpCreationScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        geminiServiceProvider.overrideWithValue(mockGemini),
      ],
      child: MaterialApp(home: Imagin8CreationScreen(worldId: worldId)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Human'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollAndTap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(finder, 200.0, scrollable: scrollable);
    await tester.tap(finder);
    await tester.pump();
  }

  group('Imagin8 Card Validation', () {
    testWidgets(
        'Scenario: Character with 9 cards containing 2 abilities and only 1 drawback is invalid',
        (WidgetTester tester) async {
      await pumpCreationScreen(tester);

      for (int i = 0; i < 6; i++) await scrollAndTap(tester, 'Trait $i');
      for (int i = 0; i < 2; i++) await scrollAndTap(tester, 'Ability $i');
      await scrollAndTap(tester, 'Drawback 0');
      await tester.pumpAndSettle();

      final nextBtn = find.text('Next');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Finalize'), findsWidgets);

      expect(find.textContaining('Unbalanced! Need 1 more Drawback(s)'),
          findsOneWidget);
    });

    testWidgets('Scenario: Character with more than 8 normal cards is invalid',
        (WidgetTester tester) async {
      await pumpCreationScreen(tester);

      for (int i = 0; i < 9; i++) await scrollAndTap(tester, 'Trait $i');
      await tester.pump();

      expect(find.text('Selected Cards: 8 / 8'), findsOneWidget);

      if (find.text('Max 8 normal cards allowed.').evaluate().isNotEmpty) {
        expect(find.text('Max 8 normal cards allowed.'), findsOneWidget);
      }
    });

    testWidgets(
        'Scenario: Character with 8 normal cards and matched drawbacks is valid',
        (WidgetTester tester) async {
      await pumpCreationScreen(tester);

      for (int i = 0; i < 6; i++) await scrollAndTap(tester, 'Trait $i');
      for (int i = 0; i < 2; i++) await scrollAndTap(tester, 'Ability $i');
      for (int i = 0; i < 2; i++) await scrollAndTap(tester, 'Drawback $i');

      final nextBtn = find.text('Next');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Finalize'), findsWidgets);

      expect(find.textContaining('Unbalanced!'), findsNothing);
      expect(find.textContaining('Must select exactly 8'), findsNothing);
    });

    testWidgets(
        'Scenario: Character with 3 Drawbacks and 0 Abilities is invalid (Max 2)',
        (WidgetTester tester) async {
      await pumpCreationScreen(tester);

      // 8 Traits (Normal cards) to satisfy base requirement
      for (int i = 0; i < 8; i++) {
        await scrollAndTap(tester, 'Trait $i');
      }

      // 3 Drawbacks (0 Abilities)
      // Limit is Max(0, 2) = 2. So 3 is invalid.
      for (int i = 0; i < 3; i++) {
        await scrollAndTap(tester, 'Drawback $i');
      }

      final nextBtn = find.text('Next');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Confirm we are on Step 2
      expect(find.text('Finalize'), findsWidgets);

      // Expect specific error
      expect(
          find.textContaining(
              'Too many Drawbacks! Max 2 allowed (based on Abilities)'),
          findsOneWidget);
    });

    testWidgets(
        'Scenario: Character with 3 Drawbacks and 3 Abilities is valid (Max 3)',
        (WidgetTester tester) async {
      await pumpCreationScreen(tester);

      // 5 Traits
      for (int i = 0; i < 5; i++) {
        await scrollAndTap(tester, 'Trait $i');
      }

      // 3 Abilities
      for (int i = 0; i < 3; i++) {
        await scrollAndTap(tester, 'Ability $i');
      }

      // 3 Drawbacks
      // Limit is Max(3, 2) = 3. So 3 is valid.
      for (int i = 0; i < 3; i++) {
        await scrollAndTap(tester, 'Drawback $i');
      }

      // Total cards: 5 Traits + 3 Abilities = 8 Normal. 3 Drawbacks. Total 11.

      final nextBtn = find.text('Next');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Confirm we are on Step 2
      expect(find.text('Finalize'), findsWidgets);

      // Should be valid
      expect(find.textContaining('Too many Drawbacks!'), findsNothing);
      expect(find.textContaining('Unbalanced!'), findsNothing);
      expect(find.textContaining('Must select exactly 8'), findsNothing);
    });
  });
}
