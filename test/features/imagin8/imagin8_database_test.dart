import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/features/imagin8/data/imagin8_seed.dart';
import 'test_asset_bundle.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('Schema version should be 26', () {
    expect(database.schemaVersion, 26);
  });

  test('Imagin8Cards table should be empty initially', () async {
    final cards = await database.select(database.imagin8Cards).get();
    expect(cards.isEmpty, true);
  });

  testWidgets('Imagin8Seed should populate the table', (tester) async {
    // Ensure binding is initialized for rootBundle
    TestWidgetsFlutterBinding.ensureInitialized();

    await Imagin8Seed.seed(database, bundle: TestAssetBundle());
    final cards = await database.select(database.imagin8Cards).get();
    expect(cards.isNotEmpty, true);
    expect(cards.any((c) => c.name == 'Brave'), true);
    expect(cards.any((c) => c.deck == 'Fantasy'), true);
  });

  test('Worlds table should have new columns', () async {
    final worldId = await database.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      description: 'A test world',
      system: const Value('imagin8'),
      selectedDecks: const Value('["Fantasy"]'),
    ));

    final world = await database.gameDao.getWorld(worldId);
    expect(world?.system, 'imagin8');
    expect(world?.selectedDecks, '["Fantasy"]');
  });
}
