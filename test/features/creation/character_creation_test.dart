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
      return Future.value(
          'Name,Genre,Stats,Free Traits\r\nHuman,Universal,+1 All Stats,None\r\nElf,Fantasy,+2 DEX; +1 INT,Keen Senses');
    }
    if (path.contains('Origins')) {
      return Future.value(
          'Name,Genre,Skills,Feat,Starting Items,Description\r\nWarrior,Fantasy,Athletics,Tough,Sword,A fighter.\r\nExplorer,Universal,Survival,Keen,Map,A traveler.');
    }
    if (path.contains('Genres')) {
      return Future.value(
          'Name,Description,Currency,Themes\r\nFantasy,Generic Fantasy,Gold,Magic,Monsters\r\nSci-Fi,Future stuff,Credits,Tech,Space');
    }
    if (path.contains('Skills')) {
      // Name,Genre,Attribute,Locked?,Description
      return Future.value(
          'Name,Genre,Attribute,Locked?,Description\r\nAthletics,Universal,Strength,FALSE,Run fast\r\nSurvival,Universal,Wisdom,FALSE,Survive');
    }
    // Default empty for others (Items, Feats, Attributes, Traits) to avoid parsing errors
    // We should return valid headers for them or empty with matching header length?
    // Failing to parse default is fine as long as Species works.
    return Future.value('');
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
        child: const MaterialApp(
          home: CharacterCreationScreen(worldId: 1),
        ),
      ),
    );

    // Wait for loading to complete
    // pumpAndSettle times out because CircularProgressIndicator is indeterminate and always "animating"
    int pumps = 0;
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100)); // Advance time
      pumps++;
      if (pumps > 100) {
        // fail early if it takes too long (10 seconds)
        fail("Timed out waiting for CharacterCreationScreen to load");
      }
    }

    // Check for Text
    expect(find.text('Character Creation'), findsOneWidget);

    // Verify Species are present
    // Based on the mock loader, we expect "Human".
    expect(find.text('Human'), findsOneWidget);

    // Cleanup to prevent !timersPending
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
