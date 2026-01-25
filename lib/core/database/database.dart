import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

enum MessageRole {
  user,
  ai,
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => textEnum<MessageRole>()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class Worlds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get genre => text()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Character extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get heroClass => text()();
  TextColumn get species => text().withDefault(const Constant('Human'))();
  IntColumn get level => integer()();
  IntColumn get currentHp => integer()();
  IntColumn get maxHp => integer()();
  IntColumn get gold => integer()();
  TextColumn get location => text()();
  IntColumn get worldId => integer().nullable().references(Worlds, #id)();
}

class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get characterId => integer().references(Character, #id)();
  TextColumn get itemName => text()();
  IntColumn get quantity => integer()();
}

@DriftDatabase(
    tables: [ChatMessages, Character, Inventory, Worlds], daos: [GameDao])
class AppDatabase extends _$AppDatabase {
  final int instanceId = DateTime.now().millisecondsSinceEpoch;
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection()) {
    print('🏗️ DATABASE CREATED! Instance ID: $instanceId');
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Create the Worlds table
          await m.createTable(worlds);

          // Add worldId column to Character table
          await m.addColumn(character, character.worldId);

          // Create a Legacy World for existing data
          final legacyWorldId =
              await into(worlds).insert(WorldsCompanion.insert(
            name: 'Legacy Save',
            genre: 'Unknown',
            description: 'Migrated from previous version',
          ));

          // Link existing characters to the Legacy World
          await (update(character)..where((t) => t.worldId.isNull()))
              .write(CharacterCompanion(worldId: Value(legacyWorldId)));
        }
        if (from < 3) {
          // Add species column
          await m.addColumn(character, character.species);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftAccessor(tables: [ChatMessages, Character, Inventory, Worlds])
class GameDao extends DatabaseAccessor<AppDatabase> with _$GameDaoMixin {
  GameDao(super.db);

  Future<int> insertMessage(String role, String content) {
    return into(chatMessages).insert(ChatMessagesCompanion(
      role: Value(MessageRole.values.firstWhere((e) => e.name == role)),
      content: Value(content),
    ));
  }

  Future<List<ChatMessage>> getRecentMessages(int limit) {
    return (select(chatMessages)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  Future<void> updateHp(int id, int newHp) {
    return (update(character)..where((tbl) => tbl.id.equals(id)))
        .write(CharacterCompanion(currentHp: Value(newHp)));
  }

  Future<void> updateCharacterStats(CharacterCompanion stats) {
    // Assuming we are updating a single character or creating if not exists.
    // Use insertOnConflictUpdate for robustness if id is set.
    return into(character).insertOnConflictUpdate(stats);
  }

  Future<bool> updateCharacter(CharacterData entry) =>
      update(character).replace(entry);

  Future<void> forceUpdateHp(int id, int newHp) async {
    // Using simple statement. Table name matches the class Character -> character (default Drift behavior)
    // Note: Column names are snake_case by default in Drift unless named otherwise.
    // Character class fields: currentHp -> current_hp ?
    // Usually Drift maps camelCase fields to snake_case columns.
    await customStatement(
      'UPDATE character SET current_hp = ? WHERE id = ?',
      [newHp, id],
    );
    // Force a notification to listeners (just in case we switch back to streams later)
    // This is a bit of a hack since we aren't using streams anymore, but good for completeness.
    // Also valid to just perform the query.
  }

  Future<void> updateGold(int id, int newGold) {
    return (update(character)..where((tbl) => tbl.id.equals(id)))
        .write(CharacterCompanion(gold: Value(newGold)));
  }

  Future<void> updateLocation(int id, String newLocation) {
    return (update(character)..where((tbl) => tbl.id.equals(id)))
        .write(CharacterCompanion(location: Value(newLocation)));
  }

  Future<void> addItem(int characterId, String name) async {
    final item = await (select(inventory)
          ..where((t) =>
              t.characterId.equals(characterId) & t.itemName.equals(name)))
        .getSingleOrNull();

    if (item != null) {
      await update(inventory)
          .replace(item.copyWith(quantity: item.quantity + 1));
    } else {
      await into(inventory).insert(InventoryCompanion(
        characterId: Value(characterId),
        itemName: Value(name),
        quantity: const Value(1),
      ));
    }
  }

  Future<void> removeItem(int characterId, String name) async {
    final item = await (select(inventory)
          ..where((t) =>
              t.characterId.equals(characterId) & t.itemName.equals(name)))
        .getSingleOrNull();

    if (item != null) {
      if (item.quantity > 1) {
        await update(inventory)
            .replace(item.copyWith(quantity: item.quantity - 1));
      } else {
        await (delete(inventory)..where((t) => t.id.equals(item.id))).go();
      }
    }
  }

  Future<CharacterData?> getCharacter(int worldId) {
    return (select(character)
          ..where((t) => t.worldId.equals(worldId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<CharacterData>> getAllCharacters() => select(character).get();

  Stream<CharacterData?> watchCharacter(int worldId) {
    return (select(character)
          ..where((t) => t.worldId.equals(worldId))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<List<InventoryData>> getInventory() {
    return select(inventory).get();
  }

  Future<List<InventoryData>> getInventoryForCharacter(int characterId) {
    return (select(inventory)..where((t) => t.characterId.equals(characterId)))
        .get();
  }

  Stream<List<InventoryData>> watchInventory() {
    return select(inventory).watch();
  }

  Future<int> debugCountCharacters() async {
    final result =
        await customSelect('SELECT count(*) as c FROM character').getSingle();
    return result.data['c'] as int;
  }

  // -- NEW WORLD METHODS --
  Future<int> createWorld(WorldsCompanion world) {
    return into(worlds).insert(world);
  }

  Future<List<World>> getAllWorlds() {
    return select(worlds).get();
  }

  Future<World?> getWorld(int id) {
    return (select(worlds)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Update character bio after creation screen finishes.
  Future<void> updateCharacterBio({
    required int characterId,
    required String name,
    required String characterClass,
    required String species,
    required int level,
    required int maxHp,
  }) async {
    await (update(character)..where((t) => t.id.equals(characterId))).write(
      CharacterCompanion(
        name: Value(name),
        heroClass: Value(characterClass),
        species: Value(species),
        level: Value(level),
        currentHp: Value(maxHp),
        maxHp: Value(maxHp),
      ),
    );
  }
}
