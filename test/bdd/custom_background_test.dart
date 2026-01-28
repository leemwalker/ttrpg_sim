import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';

import '../shared_test_utils.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

void main() {
  testWidgets('Custom Background Flow', (WidgetTester tester) async {
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
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Testing backgrounds',
    ));

    // Create placeholder
    final charId = await dao.updateCharacterStats(CharacterCompanion.insert(
      name: "Traveler",
      species: const drift.Value("Human"),
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: "Start",
      worldId: drift.Value(worldId),
    ));

    // 2. Pump Screen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CharacterCreationScreen(worldId: worldId, characterId: charId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Fill Basic Info
    await tester.enterText(
        find.widgetWithText(TextField, 'Character Name'), 'Custom Hero');

    // 4. Select Custom Background
    final backgroundDropdown =
        find.byKey(const Key('backgroundDropdown')).first;
    await tester.ensureVisible(backgroundDropdown);
    await tester.tap(backgroundDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    // 5. Verify New Fields Appear
    expect(find.byKey(const Key('customBackgroundNameField')).first,
        findsOneWidget);
    expect(
        find.byKey(const Key('customFeatureDropdown')).first, findsOneWidget);
    expect(find.byKey(const Key('customOriginFeatDropdown')).first,
        findsOneWidget);

    // 6. Fill Custom Details
    await tester.enterText(
        find.byKey(const Key('customBackgroundNameField')).first, 'Wanderer');

    // Select Feature
    final featureDropdown =
        find.byKey(const Key('customFeatureDropdown')).first;
    await tester.ensureVisible(featureDropdown);
    await tester.tap(featureDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criminal Contact').last);
    await tester.pumpAndSettle();

    // Select Feat
    final featDropdown =
        find.byKey(const Key('customOriginFeatDropdown')).first;
    await tester.ensureVisible(featDropdown);
    await tester.tap(featDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alert').last);
    await tester.pumpAndSettle();

    // Select Skills (2 fixed) - Using Text finder for label is okay if unique,
    // or we could add keys to the dynamic list.
    // For now, let's look for known labels which should be unique enough in this form.
    // Select Skills
    final skill1 = find.text('Skill 1');
    await tester.ensureVisible(skill1);
    await tester.tap(skill1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acrobatics').last);
    await tester.pumpAndSettle();

    final skill2 = find.text('Skill 2');
    await tester.ensureVisible(skill2);
    await tester.tap(skill2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stealth').last);
    await tester.pumpAndSettle();

    // 7. Create
    final createBtn = find.byKey(const Key('createCharacterButton')).first;
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // 8. Verify Data in DB
    final char = await dao.getCharacterById(charId);
    expect(char, isNotNull);
    expect(char!.name, 'Custom Hero');
    expect(char.background, 'Custom: Wanderer');

    // We expect the details to be in the backstory (appended)
    // Since original backstory was empty, it should just be the custom details
    expect(char.backstory, contains('Feature: Criminal Contact'));
    expect(char.backstory, contains('Origin Feat: Alert'));
    expect(char.backstory, contains('Skills: Acrobatics, Stealth'));
  });
}
