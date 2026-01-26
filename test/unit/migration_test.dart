import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ttrpg_sim/core/database/database.dart';

void main() {
  test('Database creates with current schema successfully', () async {
    // Create a fresh in-memory database with current schema
    final sqlite3Db = sqlite3.openInMemory();
    final db = AppDatabase(NativeDatabase.opened(sqlite3Db));

    // Create a world
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      description: 'A test world',
    ));

    // Verify world was created with all current columns
    final world = await db.gameDao.getWorld(worldId);
    expect(world, isNotNull);
    expect(world!.name, 'Test World');
    expect(world.tone, 'Standard', reason: 'Default tone should be Standard');

    // Create a character linked to the world
    await db.into(db.character).insert(CharacterCompanion.insert(
          name: 'Test Hero',
          heroClass: 'Fighter',
          level: 1,
          currentHp: 10,
          maxHp: 10,
          gold: 0,
          location: 'Town',
          worldId: Value(worldId),
        ));

    // Verify character was created with all current columns
    final character = await db.gameDao.getCharacter(worldId);
    expect(character, isNotNull);
    expect(character!.name, 'Test Hero');
    expect(character.strength, 10, reason: 'Default strength should be 10');
    expect(character.inventory, '[]',
        reason: 'Default inventory should be empty array');

    await db.close();
    sqlite3Db.dispose();
  });
}
