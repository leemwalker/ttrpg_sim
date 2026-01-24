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

class Character extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get heroClass => text()();
  IntColumn get level => integer()();
  IntColumn get currentHp => integer()();
  IntColumn get maxHp => integer()();
  IntColumn get gold => integer()();
  TextColumn get location => text()();
}

class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get characterId => integer().references(Character, #id)();
  TextColumn get itemName => text()();
  IntColumn get quantity => integer()();
}

@DriftDatabase(tables: [ChatMessages, Character, Inventory], daos: [GameDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftAccessor(tables: [ChatMessages, Character, Inventory])
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

  Future<void> updateCharacterStats(CharacterCompanion stats) {
    // Assuming we are updating a single character or creating if not exists.
    // Use insertOnConflictUpdate for robustness if id is set.
    return into(character).insertOnConflictUpdate(stats);
  }

  Future<void> addItem(String name) async {
    final item = await (select(inventory)
          ..where((t) => t.itemName.equals(name)))
        .getSingleOrNull();

    if (item != null) {
      await update(inventory)
          .replace(item.copyWith(quantity: item.quantity + 1));
    } else {
      // Assuming a default character ID of 1 for single player MVP.
      await into(inventory).insert(InventoryCompanion(
        characterId: const Value(1),
        itemName: Value(name),
        quantity: const Value(1),
      ));
    }
  }

  Future<void> removeItem(String name) async {
    final item = await (select(inventory)
          ..where((t) => t.itemName.equals(name)))
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

  Future<CharacterData?> getCharacter() {
    // Assuming single character for now, or get the first one
    return (select(character)..limit(1)).getSingleOrNull();
  }

  Future<List<InventoryData>> getInventory() {
    return select(inventory).get();
  }
}
