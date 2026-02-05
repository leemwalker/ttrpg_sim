import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'mock_gemini_service.dart';
import '../shared_test_utils.dart';

/// BDD Tests: Character creation at each difficulty level, with and without magic
void main() {
  late MockRuleDataLoader mockLoader;
  late AppDatabase db;
  late MockGeminiService mockGemini;

  setUp(() {
    mockLoader = MockRuleDataLoader();
    mockLoader.setupDefaultRules();

    // Add magic-enabling trait for magic tests
    mockLoader.setResponse(
        'assets/system/d20/Traits.csv',
        'Name,Type,Cost,Genre,Desc,Effect\r\n'
            'Gifted,Positive,1,Universal,Magic talent,Unlock Magic');

    // Add Spellcasting locked skill for magic section visibility
    mockLoader.setResponse(
        'assets/system/d20/Skills.csv',
        'Name,Genre,Attr,Locked,Desc\r\n'
            'Athletics,Universal,STR,FALSE,Run\r\n'
            'Spellcasting,Fantasy,INT,TRUE,Cast magic');

    // Add Mage origin that grants Spellcasting skill
    mockLoader.setResponse(
        'assets/system/d20/Origins.csv',
        'Name,Genre,Skills,Feat,Items,Desc\r\n'
            'Refugee,Universal,Athletics,None,,Survivor\r\n'
            'Mage,Fantasy,Spellcasting,Arcane Student,,Trained in arcane arts');

    // Add feat that unlocks spellcasting
    mockLoader.setResponse(
        'assets/system/d20/Feats.csv',
        'Name,Genre,Type,Pre,Desc,Effect\r\n'
            'None,Universal,Special,None,No Feat,None\r\n'
            'Arcane Student,Fantasy,Magic,None,Study magic,Unlock Spellcasting');

    final inMemoryExecutor = NativeDatabase.memory();
    db = AppDatabase(inMemoryExecutor);
    mockGemini = MockGeminiService();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createWorld({
    required GameDifficulty difficulty,
    required bool magicEnabled,
  }) async {
    return db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      genres: const Value('["Fantasy"]'),
      description: 'Test',
      isMagicEnabled: Value(magicEnabled),
      difficulty: Value(difficulty.name),
    ));
  }

  Future<void> pumpCreationScreen(WidgetTester tester, int worldId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: MaterialApp(
          home: CharacterCreationScreen(worldId: worldId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeBasicCreation(WidgetTester tester,
      {required String name}) async {
    // Step 1: Name & Species
    await tester.enterText(find.byType(TextField).first, name);
    await tester.tap(find.byKey(const ValueKey('species_option_Human')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 2: Origin
    await tester.tap(find.byKey(const ValueKey('origin_option_Refugee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 3: Traits (skip)
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 4: Attributes (skip/defaults)
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 5: Skills/Magic (finish)
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();
  }

  Future<void> completeMagicCreation(WidgetTester tester,
      {required String name}) async {
    // Step 1: Name & Species
    await tester.enterText(find.byType(TextField).first, name);
    await tester.tap(find.byKey(const ValueKey('species_option_Human')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 2: Origin - Select Mage (grants Spellcasting at Rank 1)
    await tester.tap(find.byKey(const ValueKey('origin_option_Mage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 3: Traits (skip - Mage origin already unlocks magic via Spellcasting)
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 4: Attributes (skip/defaults)
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();

    // Step 5: Skills/Magic - select pillar
    await tester.tap(find.byKey(const ValueKey('magic_pillar_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matter').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('magic_description_field')),
        'Elemental Control');
    await tester.pumpAndSettle();

    // Finish
    await tester.tap(find.byKey(const ValueKey('nav_next_button')));
    await tester.pumpAndSettle();
  }

  group('Character Creation by Difficulty - Without Magic', () {
    for (final difficulty in GameDifficulty.values) {
      testWidgets('Creates character at ${difficulty.name} difficulty',
          (WidgetTester tester) async {
        mockLoader.setTestScreenSize(tester);
        await ModularRulesController().loadRules(loader: mockLoader);

        // GIVEN: A world with specified difficulty and magic disabled
        final worldId =
            await createWorld(difficulty: difficulty, magicEnabled: false);

        await pumpCreationScreen(tester, worldId);

        // WHEN: I complete character creation
        await completeBasicCreation(tester, name: '${difficulty.name}Hero');

        // THEN: Character exists in database
        final char = await db.gameDao.getCharacter(worldId);
        expect(char, isNotNull,
            reason: 'Character should be saved at ${difficulty.name}');
        expect(char!.name, '${difficulty.name}Hero');
        expect(char.species, 'Human');
      });
    }
  });

  group('Character Creation by Difficulty - With Magic', () {
    for (final difficulty in GameDifficulty.values) {
      testWidgets('Creates magic character at ${difficulty.name} difficulty',
          (WidgetTester tester) async {
        mockLoader.setTestScreenSize(tester);
        await ModularRulesController().loadRules(loader: mockLoader);

        // GIVEN: A world with specified difficulty and magic enabled
        final worldId =
            await createWorld(difficulty: difficulty, magicEnabled: true);

        await pumpCreationScreen(tester, worldId);

        // WHEN: I complete character creation with magic
        await completeMagicCreation(tester, name: '${difficulty.name}Mage');

        // THEN: Character exists with magic pillar set
        final char = await db.gameDao.getCharacter(worldId);
        expect(char, isNotNull,
            reason: 'Magic character should be saved at ${difficulty.name}');
        expect(char!.name, '${difficulty.name}Mage');
        expect(char.backstory, contains('Magic Pillar: Matter'),
            reason: 'Magic pillar should be recorded');
      });
    }
  });
}
