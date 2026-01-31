import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'mock_gemini_service.dart';
import '../shared_test_utils.dart';

void main() {
  late MockRuleDataLoader mockLoader;
  late AppDatabase db;
  late MockGeminiService mockGemini;

  setUp(() {
    mockLoader = MockRuleDataLoader();
    mockLoader.setupDefaultRules();

    // Add Archetype-specific rules to mock loader
    mockLoader.setResponse(
        'assets/system/Genres.csv',
        'Name,Description,Currency,Themes\r\n'
            'Fantasy,Magic worlds,GP,Magic\r\n'
            'Superhero,Power worlds,Credits,Powers\r\n'
            'Horror,Fear worlds,USD,Fear');

    mockLoader.setResponse(
        'assets/system/Species.csv',
        'Name,Genre,Stats,Free Traits\r\n'
            'Human,Universal,,None\r\n'
            'Elf,Fantasy,,None\r\n'
            'Mutant,Superhero,,None\r\n'
            'Ghost,Horror,,None');

    mockLoader.setResponse(
        'assets/system/Skills.csv',
        'Name,Genre,Attr,Locked,Desc\r\n'
            'Athletics,Universal,STR,FALSE,Run\r\n'
            'Spellcasting,Fantasy,INT,TRUE,Cast\r\n'
            'Power Control,Superhero,WIS,FALSE,Finesse\r\n'
            'Exorcism,Horror,CHA,TRUE,Banish');

    mockLoader.setResponse(
        'assets/system/Origins.csv',
        'Name,Genre,Skills,Feat,Items,Desc\r\n'
            'Mage,Fantasy,Spellcasting,Arcane Student,,Trained\r\n'
            'Hero,Superhero,Power Control,None,,Champion\r\n'
            'Priest,Horror,Exorcism,None,,Holy');

    mockLoader.setResponse(
        'assets/system/Feats.csv',
        'Name,Genre,Type,Pre,Desc,Effect\r\n'
            'Arcane Student,Fantasy,Magic,None,Study,Unlock Spellcasting\r\n'
            'None,Universal,Special,None,None,None');

    mockLoader.setResponse(
        'assets/system/Traits.csv',
        'Name,Type,Cost,Genre,Desc,Effect\r\n'
            'Super Powered,Positive,2,Superhero,Born with it,Unlock Magic\r\n'
            'Psychic Gift,Positive,2,Horror,Eldritch sense,Unlock Magic');

    final inMemoryExecutor = NativeDatabase.memory();
    db = AppDatabase(inMemoryExecutor);
    mockGemini = MockGeminiService();
  });

  tearDown(() async {
    await db.close();
  });

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

  group('Magic Archetype Creation - BDD Widget Tests', () {
    testWidgets('Fantasy Mage - Matter Pillar', (WidgetTester tester) async {
      mockLoader.setTestScreenSize(tester);
      await ModularRulesController().loadRules(loader: mockLoader);

      // GIVEN: A Fantasy world with magic enabled
      await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'Magic Realm',
        genre: 'Fantasy',
        genres: const Value('["Fantasy"]'),
        description: 'Test',
        isMagicEnabled: const Value(true),
      ));
      const worldId = 1;

      await pumpCreationScreen(tester, worldId);

      // WHEN I enter "Gandalf"
      await tester.enterText(find.byType(TextField).first, 'Gandalf');

      // AND select Elf species
      await tester.tap(find.byKey(const ValueKey('species_option_Elf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 2: Select Mage origin
      await tester.tap(find.byKey(const ValueKey('origin_option_Mage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 3: Traits (Skip)
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 4: Attributes (Skip/Defaults)
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 5: Magic
      // Verify Spellcasting is Rank 1 (from Origin)
      expect(find.text('Spellcasting'), findsOneWidget);
      expect(find.text('Rank 1'), findsOneWidget);

      // Verify Magic section shows up
      expect(find.text('Magic Expression'), findsOneWidget);

      // Choose Matter Pillar
      await tester.tap(find.byKey(const ValueKey('magic_pillar_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matter').last);
      await tester.pumpAndSettle();

      // Enter Description
      await tester.enterText(
          find.byKey(const ValueKey('magic_description_field')),
          'Elemental Stone Shaper');
      await tester.pumpAndSettle();

      // Finish
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // THEN: Verify character in DB
      final char = await db.gameDao.getCharacter(worldId);
      expect(char!.name, 'Gandalf');
      expect(char.species, 'Elf');
      expect(char.backstory, contains('Magic Pillar: Matter'));
      expect(char.backstory, contains('Elemental Stone Shaper'));
    });

    testWidgets('Superhero Blaster - Energy Pillar',
        (WidgetTester tester) async {
      mockLoader.setTestScreenSize(tester);
      await ModularRulesController().loadRules(loader: mockLoader);

      // GIVEN: A Superhero world with magic/powers enabled
      await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'Metro City',
        genre: 'Superhero',
        genres: const Value('["Superhero"]'),
        description: 'Test',
        isMagicEnabled: const Value(true),
      ));
      const worldId = 1;

      await pumpCreationScreen(tester, worldId);

      // WHEN I enter "BlastForce"
      await tester.enterText(find.byType(TextField).first, 'BlastForce');

      // AND select Mutant species
      await tester.tap(find.byKey(const ValueKey('species_option_Mutant')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 2: Select Hero origin
      await tester.tap(find.byKey(const ValueKey('origin_option_Hero')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 3: Enable "Super Powered" Trait (Required for Magic logic in this build)
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 4: Attributes
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 5: Magic
      // We need to rank up "Power Control" to 1 to unlock magic section
      await tester.tap(find.byKey(const ValueKey('skill_add_Power Control')));
      await tester.pumpAndSettle();

      // Choose Energy Pillar
      await tester.tap(find.byKey(const ValueKey('magic_pillar_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Energy').last);
      await tester.pumpAndSettle();

      // Enter Description
      await tester.enterText(
          find.byKey(const ValueKey('magic_description_field')),
          'Force Projectors');
      await tester.pumpAndSettle();

      // Finish
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // THEN: Verify character in DB
      final char = await db.gameDao.getCharacter(worldId);
      expect(char!.name, 'BlastForce');
      expect(char.backstory, contains('Magic Pillar: Energy'));
    });

    testWidgets('Horror Psychic - Mind Pillar', (WidgetTester tester) async {
      mockLoader.setTestScreenSize(tester);
      await ModularRulesController().loadRules(loader: mockLoader);

      // GIVEN: A Horror world with magic enabled
      await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'Silent Hill',
        genre: 'Horror',
        genres: const Value('["Horror"]'),
        description: 'Test',
        isMagicEnabled: const Value(true),
      ));
      const worldId = 1;

      await pumpCreationScreen(tester, worldId);

      // WHEN I enter "The Specter"
      await tester.enterText(find.byType(TextField).first, 'The Specter');

      // AND select Ghost species
      await tester.tap(find.byKey(const ValueKey('species_option_Ghost')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 2: Select Priest origin
      await tester.tap(find.byKey(const ValueKey('origin_option_Priest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 3: Add "Psychic Gift" Trait
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 4: Attributes
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // Step 5: Magic
      // Exorcism is already Rank 1 from Priest
      expect(find.text('Exorcism'), findsOneWidget);

      // Choose Mind Pillar
      await tester.tap(find.byKey(const ValueKey('magic_pillar_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mind').last);
      await tester.pumpAndSettle();

      // Enter Description
      await tester.enterText(
          find.byKey(const ValueKey('magic_description_field')),
          'Telepathic Scream');
      await tester.pumpAndSettle();

      // Finish
      await tester.tap(find.byKey(const ValueKey('nav_next_button')));
      await tester.pumpAndSettle();

      // THEN: Verify character in DB
      final char = await db.gameDao.getCharacter(worldId);
      expect(char!.name, 'The Specter');
      expect(char.backstory, contains('Magic Pillar: Mind'));
      expect(char.backstory, contains('Telepathic Scream'));
    });
  });
}
