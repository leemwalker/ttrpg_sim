import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart'; // For BuildContext? Maybe not needed if using keys or returning status. But FilePicker might need it? No.
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:intl/intl.dart';

class BackupService {
  final AppDatabase db;
  final GameDao dao;

  BackupService(this.db) : dao = db.gameDao;

  /// Serialization Version
  static const int _version = 1;

  /// internal: Generate JSON string from DB data
  Future<String> generateBackupJson(int worldId) async {
    // 1. Fetch Data
    final world = await dao.getWorld(worldId);
    if (world == null) throw Exception("World not found");

    final character = await dao.getCharacter(worldId);
    if (character == null) throw Exception("Character not found");

    final quests = await (db.select(db.quests)
          ..where((t) => t.worldId.equals(worldId)))
        .get();

    // Fetch Inventory (since it's a separate table now)
    final inventory = await dao.getInventoryForCharacter(character.id);

    final messages = await (db.select(db.chatMessages)
          ..where((t) => t.worldId.equals(worldId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
        .get();

    // 2. Serialize
    final Map<String, dynamic> data = {
      'version': _version,
      'timestamp': DateTime.now().toIso8601String(),
      'world': world.toJson(),
      'character': character.toJson(),
      'inventory': inventory.map((e) => e.toJson()).toList(),
      'quests': quests.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  /// Export a full campaign (World, Character, Chat, Quests)
  Future<void> exportCampaign(int worldId) async {
    final jsonString = await generateBackupJson(worldId);
    final world = await dao.getWorld(
        worldId); // Re-fetch name for filename (optimized: could pass it)

    // 3. File Creation
    final directory = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final sanitizedWorldName =
        world!.name.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final fileName = 'save_${sanitizedWorldName}_$dateStr.json';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(jsonString);

    // 4. Share
    await Share.shareXFiles([XFile(file.path)],
        text: 'Campaign Backup: ${world.name}');
  }

  /// internal: Restore data from JSON string
  Future<void> restoreBackupJson(String content) async {
    final Map<String, dynamic> data = jsonDecode(content);

    // Check Version
    // if (data['version'] != _version) ... handle migration if needed

    // 2. Restore Logic (Transaction)
    await db.transaction(() async {
      // A. Import World
      final worldMap = data['world'] as Map<String, dynamic>;
      // Remove ID to auto-increment
      worldMap.remove('id');
      // Ensure unique name? Maybe append (Imported)?
      worldMap['name'] = "${worldMap['name']} (Imported)";

      final worldId = await db.into(db.worlds).insert(WorldsCompanion.insert(
            name: worldMap['name'],
            genre: worldMap['genre'],
            description: worldMap['description'],
            system: Value(worldMap['system'] ?? 'd20'), // Default if missing
            selectedDecks: Value(worldMap['selectedDecks']),
            isMagicEnabled: Value(worldMap['isMagicEnabled'] ?? false),
            tone: Value(worldMap['tone'] ?? 'Standard'),
            difficulty: Value(worldMap['difficulty'] ?? 'Medium'),
            speciesConfig: Value(worldMap['speciesConfig'] ?? '{}'),
            // createdAt: defaults to now
          ));

      // B. Import Character
      final charMap = data['character'] as Map<String, dynamic>;
      charMap.remove('id');

      final charId =
          await db.into(db.character).insert(CharacterCompanion.insert(
                name: charMap['name'],
                worldId: Value(worldId), // Link to new World
                level: charMap['level'],
                currentHp: charMap['currentHp'],
                maxHp: charMap['maxHp'],
                gold: charMap['gold'],
                location: charMap['location'],
                species: Value(charMap['species'] ?? 'Human'),
                origin: Value(charMap['origin'] ?? 'Unknown'),
                background: Value(charMap['background']),
                backstory: Value(charMap['backstory']),
                attributes: Value(charMap['attributes'] ?? '{}'),
                skills: Value(charMap['skills'] ?? '{}'),
                traits: Value(charMap['traits'] ?? '[]'),
                feats: Value(charMap['feats'] ?? '[]'),
                spells: Value(charMap['spells'] ?? '[]'),
                equipment: Value(charMap['equipment'] ?? '{}'),
                magicPillar: Value(charMap['magicPillar']),
                currentMana: Value(charMap['currentMana'] ?? 0),
                maxMana: Value(charMap['maxMana'] ?? 10),
                xp: Value(charMap['xp'] ?? 0),
                hand: Value(charMap['hand']),
                discardPile: Value(charMap['discardPile']),
              ));

      // C. Import Inventory (if present)
      if (data.containsKey('inventory')) {
        final invList = data['inventory'] as List;
        for (final itemData in invList) {
          final itemMap = itemData as Map<String, dynamic>;
          await db.into(db.inventory).insert(InventoryCompanion.insert(
                characterId: charId,
                itemName: itemMap['itemName'],
                quantity: itemMap['quantity'],
              ));
        }
      }

      // D. Import Quests
      if (data.containsKey('quests')) {
        final questsList = data['quests'] as List;
        for (final qData in questsList) {
          final qMap = qData as Map<String, dynamic>;
          await db.into(db.quests).insert(QuestsCompanion.insert(
                worldId: worldId,
                title: qMap['title'],
                description: qMap['description'],
                status: qMap['status'],
              ));
        }
      }

      // E. Import Messages
      final msgList = data['messages'] as List;
      for (final msgData in msgList) {
        final msgMap = msgData as Map<String, dynamic>;

        // Handle Enum
        final roleStr = msgMap['role'] as String;
        MessageRole role;
        // Check if role is serialized as "MessageRole.user" or "user"
        // Drift toJson usually does "user" if instructed, or index?
        // Standard toString is "MessageRole.user", drift default serializer often names it.
        // Let's assume name string match for safety.
        try {
          role = MessageRole.values.firstWhere((e) => e.name == roleStr);
        } catch (_) {
          role = MessageRole.system;
        }

        await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
              role: role,
              content: msgMap['content'],
              worldId: Value(worldId),
              characterId: Value(charId),
              timestamp: Value(DateTime.parse(msgMap['timestamp'])),
            ));
      }
    });
  }

  /// Import a campaign file
  Future<void> importCampaign() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    await restoreBackupJson(content);
  }
}
