import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/database/database.dart';

void main() {
  test('Destructive Integrity Test: Deleting Dependency', () async {
    // Setup - Fresh In-Memory Database
    final db = AppDatabase(NativeDatabase.memory());
    final dao = GameDao(db);

    // 1. Create Custom Trait
    final traitId = await dao.createCustomTrait(const CustomTraitsCompanion(
      name: Value('Hacker'),
      type: Value('Class'),
      description: Value('A master of digital warfare'),
    ));

    // 2. Create Character using that trait
    // Matches "Neo", Class: "Hacker"
    // final charId =
    await dao.updateCharacterStats(const CharacterCompanion(
      name: Value('Neo'),
      heroClass: Value('Hacker'),
      level: Value(1),
      currentHp: Value(10),
      maxHp: Value(10),
      gold: Value(0),
      location: Value('Matrix'),
      // worldId is technically required or nullable depending on schema version,
      // but in V7 it's nullable references Worlds.
      // Since referential integrity is enforced by foreign keys in SQLite *if enabled*,
      // and worldId is nullable, this is fine.
      // However, the test prompt says 'Neo's class should either remain "Hacker" (String)'.
      // The class is stored as a string in `heroClass` column.
    ));

    // 3. Delete the Custom Trait
    await dao.deleteCustomTrait(traitId);

    // 4. Fetch Neo
    // We expect this NOT to fail.
    // If strict FKs were on `heroClass`, it might fail, but `heroClass` is just text.
    final neo = await (db.select(db.character)
          ..where((t) => t.name.equals('Neo')))
        .getSingle();

    // 5. Assert
    expect(neo.heroClass, 'Hacker',
        reason: "Character class should persist even if definition is deleted");

    await db.close();
  });
}
