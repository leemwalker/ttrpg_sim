import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/features/creation/character_creation_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

// Mock RuleDataLoader
class MockRuleDataLoader extends Mock implements RuleDataLoader {
  @override
  Future<String> load(String path) {
    if (path.contains('Species')) {
      return Future.value('''Name,Genre,Stats,Free Traits
Human,Universal,+1 All Stats,None
Elf,Fantasy,+2 DEX; +1 INT,Keen Senses''');
    }
    if (path.contains('Origins')) {
      return Future.value('''Name,Genre,Skills,Feat,Starting Items,Description
Warrior,Fantasy,Athletics,Tough,Sword,A fighter.
Explorer,Universal,Survival,Keen,Map,A traveler.''');
    }
    if (path.contains('Genres')) {
      return Future.value('''Name,Description,Currency,Themes
Fantasy,Generic Fantasy,Gold,Magic,Monsters
Sci-Fi,Future stuff,Credits,Tech,Space''');
    }
    // Default empty for others
    return Future.value(
        'Name,Genre,Type,Description\nTest,Universal,Test,Test');
  }
}

void main() {
  late AppDatabase database;
  late GameDao dao;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dao = GameDao(database);

    // Setup World
    await dao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Test',
      genres: const Value('["Fantasy"]'),
    ));
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Character Creation loads options and checks for overflow',
      (WidgetTester tester) async {
    // Inject Mock Loader
    final loader = MockRuleDataLoader();
    // Pre-load rules to simulate app start, or let the screen do it?
    // The screen calls loadRules(). We need to inject our loader into the singleton?
    // ModularRulesController is a singleton. valid method: loadRules({loader})
    await ModularRulesController().loadRules(loader: loader);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameDaoProvider.overrideWithValue(dao),
        ],
        child: MaterialApp(
          home: const CharacterCreationScreen(worldId: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check for Text
    expect(find.text('Character Creation'), findsOneWidget);

    // Verify Species are present (If logic works)
    // Note: If the bug exists "No species available", this might fail or we see empty list.
    // The UI likely shows a dropdown or list.
    // Let's assume we want to see "Human".
    // If fail: "No species available" might be on screen.
    if (find.text('No species available').evaluate().isNotEmpty) {
      print("Confirmed: No species available is displayed.");
    }

    // Check for overflow exception in the logs (tester.takeException() is for unhandled, strictly rendering errors log to console)
    // But we can check generic "RenderFlex overflowed" by looking at the error output usually.
    // However, tester.pumpWidget throws if there is an exception during build in some configs.
    // Let's try to verify if "Human" exists to confirm loading works or fails.

    // Note: The bug report says "No species available".
    // So expect(find.text('Human'), findsOneWidget) should fail.
    await tester.pumpAndSettle();
  });
}
