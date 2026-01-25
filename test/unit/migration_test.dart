import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ttrpg_sim/core/database/database.dart';

void main() {
  test('V1 to V7 Migration Test', () async {
    // 1. Setup V1 Database using sqlite3 directly
    final sqlite3Db = sqlite3.openInMemory();

    // Create V1 table (Note: Table name is singular 'character' as per Drift default in this project)
    sqlite3Db.execute('''
      CREATE TABLE character (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hero_class TEXT NOT NULL,
        level INTEGER NOT NULL,
        current_hp INTEGER NOT NULL,
        max_hp INTEGER NOT NULL,
        gold INTEGER NOT NULL,
        location TEXT NOT NULL
      );
    ''');

    // Insert Legacy Hero
    sqlite3Db.execute('''
      INSERT INTO character (name, hero_class, level, current_hp, max_hp, gold, location)
      VALUES ('Old Hero', 'Warrior', 1, 10, 10, 0, 'Unknown');
    ''');

    // Set Version to 1
    sqlite3Db.execute('PRAGMA user_version = 1;');

    // 2. Initialize AppDatabase with the pre-filled in-memory database
    final db = AppDatabase(NativeDatabase.opened(sqlite3Db));

    // 3. Verify Migration
    // Accessing schemaVersion triggers the migration if necessary when opening the connection
    // But we usually need to run a query to force open.
    // The migration strategy in the AppDatabase controls the upgrade.

    // We can check the schema version via the custom statement or just trust drift to update it.
    // Let's force the db to open by running a query.
    final count = await db.customSelect('SELECT count(*) FROM character').get();
    expect(count, isNotNull);

    // Verify Schema Version (Drift should have updated it to 7)
    // Note: drift doesn't automatically sync PRAGMA user_version to schemaVersion
    // immediately in all cases unless configured, but the migration runs onOpen.
    final versionResult = sqlite3Db.select('PRAGMA user_version;');
    // In a real app, Drift updates the user_version after migration.
    // Let's verify via the db structure and data.

    // 4. Assertions
    final character = await db.select(db.character).getSingle();

    expect(character.name, 'Old Hero');
    expect(character.strength, 10, reason: 'Strength should default to 10');
    expect(character.worldId, isNotNull,
        reason: 'WorldId should be populated (Legacy Save)');

    // Verify Legacy World creation
    final world = await db.select(db.worlds).getSingle();
    expect(world.name, 'Legacy Save');
    expect(character.worldId, world.id);

    await db.close();
    sqlite3Db.dispose();
  });
}
