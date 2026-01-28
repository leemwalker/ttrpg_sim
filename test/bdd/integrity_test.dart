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
    await dao.updateCharacterStats(const CharacterCompanion(
      name: Value('Neo'),
      species: Value('Hacker'), // Storing as species for this test (or Origin)
      level: Value(1),
      currentHp: Value(10),
      maxHp: Value(10),
      gold: Value(0),
      location: Value('Matrix'),
    ));

    // 3. Delete the Custom Trait
    await dao.deleteCustomTrait(traitId);

    // 4. Fetch Neo
    final neo = await (db.select(db.character)
          ..where((t) => t.name.equals('Neo')))
        .getSingle();

    // 5. Assert
    expect(neo.species, 'Hacker',
        reason:
            "Character species should persist even if definition is deleted");

    await db.close();
  });
}
