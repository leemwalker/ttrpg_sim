import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;
  late Database sqlite3Db;

  setUp(() {
    sqlite3Db = sqlite3.openInMemory();
    db = AppDatabase(NativeDatabase.opened(sqlite3Db));
  });

  tearDown(() async {
    await db.close();
    sqlite3Db.dispose();
  });

  group('Database JSON Serialization', () {
    test('Round-trip integrity of JSON attributes, skills, and traits',
        () async {
      // 1. Create a World
      final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'JSON Test World',
        genre: 'Sci-Fi',
        description: 'Testing JSON',
      ));

      // 2. Define complex JSON data
      final attributes = {'Strength': 10, 'Agility': 15, 'Tech': 8};
      final skills = {'Hacking': 5, 'Stealth': 2};
      final traits = [
        {'name': 'Cyborg', 'effects': 'Night Vision'},
        {'name': 'Hacker', 'effects': '+2 Tech'}
      ];
      final feats = [
        {'name': 'Double Jump'}
      ];

      // 3. Insert Character with this data
      // Note: usage of jsonEncode to simulate what the UI/Controller does
      await db.into(db.character).insert(CharacterCompanion.insert(
            name: 'Json Hero',
            level: 1,
            currentHp: 20,
            maxHp: 20,
            gold: 100,
            location: 'Matrix',
            worldId: Value(worldId),
            species: const Value('Android'),
            origin: const Value('Lab'),
            attributes: Value(jsonEncode(attributes)),
            skills: Value(jsonEncode(skills)),
            traits: Value(jsonEncode(traits)),
            feats: Value(jsonEncode(feats)),
          ));

      // 4. Retrieve the character
      final character = await db.gameDao.getCharacter(worldId);
      expect(character, isNotNull);

      // 5. Verify the raw string content (optional but good for debugging)
      // print('Stored Attributes: ${character!.attributes}');

      // 6. Decode and assert equality
      final retrievedAttributes =
          jsonDecode(character!.attributes) as Map<String, dynamic>;
      final retrievedSkills =
          jsonDecode(character.skills) as Map<String, dynamic>;
      final retrievedTraits = jsonDecode(character.traits) as List<dynamic>;
      final retrievedFeats = jsonDecode(character.feats) as List<dynamic>;

      expect(retrievedAttributes, equals(attributes));
      expect(retrievedSkills, equals(skills));
      expect(retrievedTraits, equals(traits));
      expect(retrievedFeats, equals(feats));
    });

    test('Handling of empty JSON defaults', () async {
      final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'Default Test World',
        genre: 'Fantasy',
        description: 'Testing Defaults',
      ));

      await db.into(db.character).insert(CharacterCompanion.insert(
            name: 'Default Hero',
            level: 1,
            currentHp: 10,
            maxHp: 10,
            gold: 0,
            location: 'Town',
            worldId: Value(worldId),
          ));

      final character = await db.gameDao.getCharacter(worldId);
      expect(character, isNotNull);

      expect(jsonDecode(character!.attributes), equals({}));
      expect(jsonDecode(character.skills), equals({}));
      expect(jsonDecode(character.traits), equals([]));
      expect(jsonDecode(character.feats), equals([]));
    });
  });
}
