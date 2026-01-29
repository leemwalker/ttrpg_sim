import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  late AppDatabase database;
  late GameDao dao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = GameDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('World Deletion should not throw SQLite error', () async {
    // 1. Create World
    final worldId = await dao.createWorld(WorldsCompanion.insert(
      name: 'For Deletion',
      genre: 'Fantasy',
      description: 'To be deleted',
    ));

    // 2. Create Character in World
    await dao.updateCharacterStats(CharacterCompanion.insert(
      name: 'Hero',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: 'Start',
      worldId: Value(worldId),
    ));

    // 3. Delete World
    try {
      await dao.deleteWorld(worldId);
      print('World deleted successfully');
    } catch (e) {
      fail('Deletion threw exception: $e');
    }

    // 4. Verify
    final world = await dao.getWorld(worldId);
    expect(world, isNull);

    final chars = await dao.getCharactersForWorld(worldId);
    expect(chars, isEmpty);
  });
}
