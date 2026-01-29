import 'dart:convert';
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
          level: 1,
          currentHp: 10,
          maxHp: 10,
          gold: 0,
          location: 'Town',
          worldId: Value(worldId),
          species: const Value('Human'),
          origin: const Value('Unknown'),
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

  test('Migration v14 -> v18 Correctly migrates FKs and Data', () async {
    final sqlite3Db = sqlite3.openInMemory();

    // 1. Manually setup v14 Schema
    // Note: We avoid complex constraints just to get the table structure 'enough' for migration to run
    // But we DO need the constraints to test the FK breakage/fix logic if possible.
    // However, sqlite3 triggers won't fire if we don't define them?
    // The migration script uses 'PRAGMA foreign_keys = ON/OFF'.

    sqlite3Db.execute(
        'PRAGMA foreign_keys = OFF;'); // Setup without worrying about order then turn on

    // Worlds
    sqlite3Db.execute('''
      CREATE TABLE worlds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        genre TEXT NOT NULL,
        tone TEXT NOT NULL DEFAULT 'Standard',
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Character (v14 setup - includes hero_class)
    sqlite3Db.execute('''
      CREATE TABLE character (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hero_class TEXT NOT NULL,
        species TEXT NOT NULL DEFAULT 'Human',
        level INTEGER NOT NULL,
        current_hp INTEGER NOT NULL,
        max_hp INTEGER NOT NULL,
        gold INTEGER NOT NULL,
        location TEXT NOT NULL,
        world_id INTEGER REFERENCES worlds(id) ON DELETE CASCADE,
        current_location_id INTEGER,
        background TEXT,
        backstory TEXT,
        inventory TEXT DEFAULT '[]',
        strength INTEGER DEFAULT 10,
        dexterity INTEGER DEFAULT 10,
        constitution INTEGER DEFAULT 10,
        intelligence INTEGER DEFAULT 10,
        wisdom INTEGER DEFAULT 10,
        charisma INTEGER DEFAULT 10,
        spells TEXT DEFAULT '[]',
        current_mana INTEGER DEFAULT 10,
        max_mana INTEGER DEFAULT 10
      );
    ''');

    // ChatMessages
    sqlite3Db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL DEFAULT 0,
        world_id INTEGER REFERENCES worlds(id) ON DELETE CASCADE,
        character_id INTEGER REFERENCES character(id) ON DELETE CASCADE
      );
    ''');

    // Inventory (old simple schema?)
    // database.dart v12 renamed inventory -> inventory_old. v18 also touches it.
    // v14 would have the 'new' inventory from v12?
    // v12 created 'inventory'.
    // v18 recreates it again.
    sqlite3Db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER REFERENCES character(id) ON DELETE CASCADE,
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL
      );
    ''');

    sqlite3Db.execute('PRAGMA foreign_keys = ON;');

    // 2. Set Version to 14
    sqlite3Db.execute('PRAGMA user_version = 14;');

    // 3. Insert Data
    sqlite3Db.execute(
        "INSERT INTO worlds (name, genre, description) VALUES ('Old World', 'Fantasy', 'Old Desc')");
    final worldId = sqlite3Db.lastInsertRowId;

    sqlite3Db.execute('''
      INSERT INTO character (name, hero_class, level, current_hp, max_hp, gold, location, world_id) 
      VALUES ('Gandalf', 'Wizard', 20, 100, 100, 500, 'Tower', $worldId)
    ''');
    final charId = sqlite3Db.lastInsertRowId;

    sqlite3Db.execute('''
      INSERT INTO chat_messages (role, content, world_id, character_id)
      VALUES ('user', 'Hello World', $worldId, $charId)
    ''');

    sqlite3Db.execute('''
      INSERT INTO inventory (character_id, item_name, quantity)
      VALUES ($charId, 'Staff', 1)
    ''');

    // 4. Migrate by opening AppDatabase
    final db = AppDatabase(NativeDatabase.opened(sqlite3Db));

    // Validating migration ran: checking schema version isn't enough, we need to access data.
    // Making a query triggers opening & migration.
    final char = await db.gameDao.getCharacterById(charId);

    // 5. Verify Data Integrity
    expect(char, isNotNull, reason: 'Character should exist after migration');
    expect(char!.name, 'Gandalf');
    // Verify heroClass is effectively gone/mapped?
    // Accessing columns relies on generated code. The generated CharacterData class now (post-codegen)
    // corresponds to the LATEST schema (v18). It does not have heroClass.
    // It should have species.
    expect(char.species, 'Human', reason: 'Should default/keep species');

    // Verify properties added in v15 are present with defaults
    // Note: In v15 migration validation, we check the JSON strings directly or their absence depending on what getCharacterById returns.
    // Ensure we are checking the properties that exist on the data class.
    expect(jsonDecode(char.attributes), equals({}));
    expect(jsonDecode(char.skills), equals({}));

    // Check Chat Message FK
    final messages = await db.gameDao.getRecentMessages(charId, 10);
    expect(messages.length, 1, reason: 'Chat message should be preserved');
    expect(messages.first.content, 'Hello World');
    expect(messages.first.characterId, charId,
        reason: 'FK should still point to character');

    // Check Inventory FK
    final inventory = await db.gameDao.getInventoryForCharacter(charId);
    expect(inventory.length, 1);
    expect(inventory.first.itemName, 'Staff');

    await db.close();
    sqlite3Db.dispose();
  });
}
