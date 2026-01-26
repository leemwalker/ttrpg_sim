import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

enum MessageRole {
  user,
  ai,
  system,
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => textEnum<MessageRole>()();
  IntColumn get worldId => integer()
      .nullable()
      .references(Worlds, #id, onDelete: KeyAction.cascade)();
  IntColumn get characterId => integer()
      .nullable()
      .references(Character, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class Worlds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get genre => text()();
  TextColumn get tone => text().withDefault(const Constant('Standard'))();
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
  IntColumn get worldId => integer()
      .nullable()
      .references(Worlds, #id, onDelete: KeyAction.cascade)();
  IntColumn get currentLocationId =>
      integer().nullable()(); // FK added after Locations table exists
  TextColumn get background => text().nullable()();
  TextColumn get backstory => text().nullable()();
  TextColumn get inventory => text().withDefault(const Constant('[]'))();
  // D&D 5e Ability Scores (default to 10 = average human)
  IntColumn get strength => integer().withDefault(const Constant(10))();
  IntColumn get dexterity => integer().withDefault(const Constant(10))();
  IntColumn get constitution => integer().withDefault(const Constant(10))();
  IntColumn get intelligence => integer().withDefault(const Constant(10))();
  IntColumn get wisdom => integer().withDefault(const Constant(10))();
  IntColumn get charisma => integer().withDefault(const Constant(10))();
}

class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get characterId => integer().references(Character, #id)();
  TextColumn get itemName => text()();
  IntColumn get quantity => integer()();
}

class Locations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get worldId =>
      integer().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g., "Riverwood"
  TextColumn get description => text()();
  TextColumn get type => text()(); // e.g., "Village", "Forest", "Dungeon"
  TextColumn get coordinates => text().nullable()(); // e.g., "0,1"
}

class PointsOfInterest extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get locationId =>
      integer().references(Locations, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g., "The Sleeping Giant Inn"
  TextColumn get description => text()();
  TextColumn get type => text()(); // e.g., "Shop", "Tavern"
}

class Npcs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get worldId =>
      integer().references(Worlds, #id, onDelete: KeyAction.cascade)();
  IntColumn get locationId => integer().nullable().references(Locations, #id,
      onDelete: KeyAction.cascade)(); // NPC might be travelling
  IntColumn get poiId => integer().nullable()(); // NPC might work at a Tavern
  TextColumn get name => text()();
  TextColumn get role => text()(); // e.g., "Blacksmith"
  TextColumn get description => text()();
  TextColumn get stats => text().nullable()(); // JSON for future combat stats
  IntColumn get relationshipScore => integer().withDefault(const Constant(0))();
}

class CustomTraits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'Species' or 'Class'
  TextColumn get description => text()();
  TextColumn get abilities => text().nullable()(); // JSON or text list
  TextColumn get stats => text().nullable()(); // JSON or text map
}

@DriftDatabase(tables: [
  ChatMessages,
  Character,
  Inventory,
  Worlds,
  Locations,
  PointsOfInterest,
  Npcs,
  CustomTraits
], daos: [
  GameDao
])
class AppDatabase extends _$AppDatabase {
  final int instanceId = DateTime.now().millisecondsSinceEpoch;
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection()) {
    print('🏗️ DATABASE CREATED! Instance ID: $instanceId');
  }

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
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
        if (from < 4) {
          // Atlas System: Create new tables
          await m.createTable(locations);
          await m.createTable(pointsOfInterest);
          await m.createTable(npcs);
          // Add currentLocationId column to Character
          await m.addColumn(character, character.currentLocationId);
        }
        if (from < 5) {
          // Dice Engine: Add ability score columns
          await m.addColumn(character, character.strength);
          await m.addColumn(character, character.dexterity);
          await m.addColumn(character, character.constitution);
          await m.addColumn(character, character.intelligence);
          await m.addColumn(character, character.wisdom);
          await m.addColumn(character, character.charisma);
        }
        if (from < 6) {
          // Add background column
          await m.addColumn(character, character.background);
        }
        if (from < 7) {
          // Add Custom Traits table
          await m.createTable(customTraits);
        }
        if (from < 8) {
          // v8 adds Cascade constraints, requires table recreation usually, but here we just moved on.
        }
        if (from < 9) {
          // Phase 1: Core Integrity
          // 1. Add worldId to chatMessages
          await m.addColumn(chatMessages, chatMessages.worldId);

          // 2. Add backstory and inventory to character
          await m.addColumn(character, character.backstory);
          await m.addColumn(character, character.inventory);
        }
        if (from < 10) {
          // Phase 2: World Creation Tone
          await m.addColumn(worlds, worlds.tone);
        }
        if (from < 11) {
          // Phase 3: Character-scoped messages for Local Shared World
          await m.addColumn(chatMessages, chatMessages.characterId);

          // Link orphan messages to most recent character in their world
          await customStatement('''
            UPDATE chat_messages
            SET character_id = (
              SELECT c.id FROM character c
              WHERE c.world_id = chat_messages.world_id
              ORDER BY c.id DESC LIMIT 1
            )
            WHERE character_id IS NULL AND world_id IS NOT NULL
          ''');
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

@DriftAccessor(tables: [
  ChatMessages,
  Character,
  Inventory,
  Worlds,
  Locations,
  PointsOfInterest,
  Npcs,
  CustomTraits
])
class GameDao extends DatabaseAccessor<AppDatabase> with _$GameDaoMixin {
  GameDao(super.db);

  Future<int> insertMessage(
      String role, String content, int? worldId, int? characterId) {
    return into(chatMessages).insert(ChatMessagesCompanion(
      role: Value(MessageRole.values.firstWhere((e) => e.name == role)),
      content: Value(content),
      worldId: Value(worldId),
      characterId: Value(characterId),
    ));
  }

  Future<List<ChatMessage>> getRecentMessages(int characterId, int limit) {
    return (select(chatMessages)
          ..where((t) => t.characterId.equals(characterId))
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

  Future<CharacterData?> getCharacterById(int characterId) {
    return (select(character)..where((t) => t.id.equals(characterId)))
        .getSingleOrNull();
  }

  Future<List<CharacterData>> getCharactersForWorld(int worldId) {
    return (select(character)..where((t) => t.worldId.equals(worldId))).get();
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

  Future<void> deleteWorld(int id) {
    return (delete(worlds)..where((t) => t.id.equals(id))).go();
  }

  /// Update character bio after creation screen finishes.
  Future<void> updateCharacterBio({
    required int characterId,
    required String name,
    required String characterClass,
    required String species,
    required String? background,
    String? backstory,
    List<String>? inventory,
    required int level,
    required int maxHp,
    int strength = 10,
    int dexterity = 10,
    int constitution = 10,
    int intelligence = 10,
    int wisdom = 10,
    int charisma = 10,
  }) async {
    await (update(character)..where((t) => t.id.equals(characterId))).write(
      CharacterCompanion(
        name: Value(name),
        heroClass: Value(characterClass),
        species: Value(species),
        background: Value(background),
        backstory: Value(backstory),
        inventory: inventory != null
            ? Value(jsonEncode(inventory))
            : const Value.absent(),
        level: Value(level),
        currentHp: Value(maxHp),
        maxHp: Value(maxHp),
        strength: Value(strength),
        dexterity: Value(dexterity),
        constitution: Value(constitution),
        intelligence: Value(intelligence),
        wisdom: Value(wisdom),
        charisma: Value(charisma),
      ),
    );
  }

  // -- ATLAS SYSTEM METHODS --

  /// Get a location by ID
  Future<Location?> getLocation(int id) {
    return (select(locations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all locations for a world
  Future<List<Location>> getLocationsForWorld(int worldId) {
    return (select(locations)..where((t) => t.worldId.equals(worldId))).get();
  }

  /// Get all POIs for a location
  Future<List<PointsOfInterestData>> getPoisForLocation(int locationId) {
    return (select(pointsOfInterest)
          ..where((t) => t.locationId.equals(locationId)))
        .get();
  }

  /// Get all NPCs at a location
  Future<List<Npc>> getNpcsForLocation(int locationId) {
    return (select(npcs)..where((t) => t.locationId.equals(locationId))).get();
  }

  /// Get all NPCs in a world
  Future<List<Npc>> getNpcsForWorld(int worldId) {
    return (select(npcs)..where((t) => t.worldId.equals(worldId))).get();
  }

  /// Get all NPCs at a POI
  Future<List<Npc>> getNpcsForPoi(int poiId) {
    return (select(npcs)..where((t) => t.poiId.equals(poiId))).get();
  }

  /// Create a new location
  Future<int> createLocation(LocationsCompanion loc) {
    return into(locations).insert(loc);
  }

  /// Create a new location from primitive values
  Future<int> createLocationFromValues({
    required int worldId,
    required String name,
    required String description,
    required String type,
    String? coordinates,
  }) {
    return into(locations).insert(LocationsCompanion.insert(
      worldId: worldId,
      name: name,
      description: description,
      type: type,
      coordinates: Value(coordinates),
    ));
  }

  /// Create a new POI
  Future<int> createPoi(PointsOfInterestCompanion poi) {
    return into(pointsOfInterest).insert(poi);
  }

  /// Create a new POI from primitive values
  Future<int> createPoiFromValues({
    required int locationId,
    required String name,
    required String description,
    required String type,
  }) {
    return into(pointsOfInterest).insert(PointsOfInterestCompanion.insert(
      locationId: locationId,
      name: name,
      description: description,
      type: type,
    ));
  }

  /// Create a new NPC
  Future<int> createNpc(NpcsCompanion npc) {
    return into(npcs).insert(npc);
  }

  /// Create a new NPC from primitive values
  Future<int> createNpcFromValues({
    required int worldId,
    required int locationId,
    required String name,
    required String role,
    required String description,
  }) {
    return into(npcs).insert(NpcsCompanion.insert(
      worldId: worldId,
      locationId: Value(locationId),
      name: name,
      role: role,
      description: description,
    ));
  }

  /// Update character's current location
  Future<void> updateCharacterLocation(int charId, int locationId) {
    return (update(character)..where((t) => t.id.equals(charId)))
        .write(CharacterCompanion(currentLocationId: Value(locationId)));
  }

  // -- HOMEBREW METHODS --

  Future<int> createCustomTrait(CustomTraitsCompanion trait) {
    return into(customTraits).insert(trait);
  }

  Future<List<CustomTrait>> getCustomTraitsByType(String type) {
    return (select(customTraits)..where((t) => t.type.equals(type))).get();
  }

  Stream<List<CustomTrait>> watchCustomTraitsByType(String type) {
    return (select(customTraits)..where((t) => t.type.equals(type))).watch();
  }

  Future<void> deleteCustomTrait(int id) {
    return (delete(customTraits)..where((t) => t.id.equals(id))).go();
  }
}
