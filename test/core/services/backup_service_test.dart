import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/backup_service.dart';

void main() {
  late AppDatabase db;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService Integration Tests', () {
    test('generateBackupJson functionality', () async {
      // 1. Seed Data
      final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      final charId =
          await db.gameDao.updateCharacterStats(CharacterCompanion.insert(
        name: 'Hero',
        worldId: Value(worldId),
        level: 1, currentHp: 10, maxHp: 10, gold: 100,
        location: 'Tavern',
        species: const Value('Human'), origin: const Value('Unknown'),
        inventory: const Value('[]'), // Old field, new is separate table
      ));

      // Add actual inventory item
      await db.into(db.inventory).insert(InventoryCompanion.insert(
            characterId: charId,
            itemName: 'Sword',
            quantity: 1,
          ));

      // Add Chat Message
      await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
            role: MessageRole.user,
            content: 'Hello World',
            worldId: Value(worldId),
            characterId: Value(charId),
            timestamp: Value(DateTime.now()),
          ));

      // 2. Generate Backup
      final jsonString = await service.generateBackupJson(worldId);

      // 3. Verify Structure
      final Map<String, dynamic> data = jsonDecode(jsonString);
      expect(data['version'], 1);
      expect(data['world']['name'], 'Test World');
      expect(data['character']['name'], 'Hero');

      final invList = data['inventory'] as List;
      expect(invList.length, 1);
      expect(invList[0]['itemName'], 'Sword');

      final msgList = data['messages'] as List;
      expect(msgList.length, 1);
      expect(msgList[0]['content'], 'Hello World');
    });

    test('restoreBackupJson functionality', () async {
      // 1. Create a valid Backup JSON
      // We simulate a backup from an "Old World" (ID 99)
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'world': {
          'id': 99, // Should be ignored
          'name': 'Restored World',
          'genre': 'Sci-Fi',
          'description': 'Imported desc',
        },
        'character': {
          'id': 50, // Should be ignored
          'worldId': 99, // Should be remapped
          'name': 'Space Ranger',
          'level': 5,
          'currentHp': 20, 'maxHp': 20, 'gold': 500,
          'location': 'Ship',
          // Required fields (nullable in Drift object but map expects them?)
          // Drift toJson usually includes all columns.
        },
        'inventory': [
          {'itemName': 'Laser Pistol', 'quantity': 1}
        ],
        'quests': [],
        'messages': [
          {
            'role': 'user',
            'content': 'Taking off!',
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]
      };

      final jsonString = jsonEncode(backupData);

      // 2. Restore
      await service.restoreBackupJson(jsonString);

      // 3. Verify Database State
      final worlds = await db.select(db.worlds).get();
      expect(worlds.length, 1);
      final newWorld = worlds.first;
      expect(newWorld.name, 'Restored World (Imported)');
      expect(newWorld.id, isNot(99)); // ID should be new (1)

      final chars = await db.select(db.character).get();
      expect(chars.length, 1);
      final newChar = chars.first;
      expect(newChar.name, 'Space Ranger');
      expect(newChar.worldId, newWorld.id); // Linked to new world

      final inv = await db.select(db.inventory).get();
      expect(inv.length, 1);
      expect(inv.first.itemName, 'Laser Pistol');
      expect(inv.first.characterId, newChar.id); // Linked to new char

      final msgs = await db.select(db.chatMessages).get();
      expect(msgs.length, 1);
      expect(msgs.first.content, 'Taking off!');
      expect(msgs.first.worldId, newWorld.id);
      expect(msgs.first.characterId, newChar.id);
    });
  });
}
