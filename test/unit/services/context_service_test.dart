import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/features/game/services/context_service.dart';

void main() {
  late AppDatabase db;
  late GameDao dao;
  late ContextService contextService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.gameDao;
    contextService = ContextService(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('ContextService', () {
    test('returns null for empty world (no locations or NPCs)', () async {
      // Create a world
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Empty World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      final result = await contextService.buildRelevantWorldData(
        worldId,
        null,
        [],
      );

      expect(result, isNull);
    });

    test('includes current location and NPCs at that location', () async {
      // Create world
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      // Create location
      final locationId = await dao.createLocationFromValues(
        worldId: worldId,
        name: 'The Tavern',
        description: 'A cozy tavern',
        type: 'Building',
      );

      // Create NPC at the location
      await dao.createNpcFromValues(
        worldId: worldId,
        locationId: locationId,
        name: 'Barkeep Bob',
        role: 'Tavern Owner',
        description: 'A friendly barkeep',
      );

      // Create NPC at different location (should NOT be included)
      final otherLocationId = await dao.createLocationFromValues(
        worldId: worldId,
        name: 'The Forest',
        description: 'A dark forest',
        type: 'Wilderness',
      );
      await dao.createNpcFromValues(
        worldId: worldId,
        locationId: otherLocationId,
        name: 'Forest Hermit',
        role: 'Loner',
        description: 'Lives alone',
      );

      final result = await contextService.buildRelevantWorldData(
        worldId,
        locationId,
        [],
      );

      expect(result, isNotNull);
      expect(result, contains('The Tavern'));
      expect(result, contains('Barkeep Bob'));
      expect(
          result, isNot(contains('Forest Hermit'))); // Should not be included
    });

    test('includes NPCs mentioned in recent chat (recency filter)', () async {
      // Create world
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      // Create NPC in a location
      final locationId = await dao.createLocationFromValues(
        worldId: worldId,
        name: 'The Forest',
        description: 'A dark forest',
        type: 'Wilderness',
      );
      await dao.createNpcFromValues(
        worldId: worldId,
        locationId: locationId,
        name: 'Lady Elara',
        role: 'Queen',
        description: 'The queen of the realm',
      );

      // Recent chat mentions Lady Elara
      final recentChat = [
        ChatMessage(
          id: 1,
          role: MessageRole.user,
          content: 'I want to meet Lady Elara',
          timestamp: DateTime.now(),
          worldId: worldId,
          characterId: 1,
        ),
        ChatMessage(
          id: 2,
          role: MessageRole.ai,
          content: 'Lady Elara is in the forest',
          timestamp: DateTime.now(),
          worldId: worldId,
          characterId: 1,
        ),
      ];

      final result = await contextService.buildRelevantWorldData(
        worldId,
        null, // No current location
        recentChat,
      );

      expect(result, isNotNull);
      expect(result, contains('Lady Elara'));
      expect(result, contains('The Forest')); // Location mentioned in chat
    });

    test('includes locations mentioned in recent chat', () async {
      // Create world
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      // Create location
      await dao.createLocationFromValues(
        worldId: worldId,
        name: 'Crystal Caves',
        description: 'Glittering caves',
        type: 'Dungeon',
      );

      // Recent chat mentions Crystal Caves
      final recentChat = [
        ChatMessage(
          id: 1,
          role: MessageRole.user,
          content: 'Tell me about the Crystal Caves',
          timestamp: DateTime.now(),
          worldId: worldId,
          characterId: 1,
        ),
      ];

      final result = await contextService.buildRelevantWorldData(
        worldId,
        null,
        recentChat,
      );

      expect(result, isNotNull);
      expect(result, contains('Crystal Caves'));
    });

    test('handles null locationId gracefully (Session Zero)', () async {
      // Create world with only NPCs (no player location)
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      final locationId = await dao.createLocationFromValues(
        worldId: worldId,
        name: 'Capital City',
        description: 'The capital',
        type: 'City',
      );

      await dao.createNpcFromValues(
        worldId: worldId,
        locationId: locationId,
        name: 'King Arthur',
        role: 'King',
        description: 'The king',
      );

      // No current location, no recent chat
      final result = await contextService.buildRelevantWorldData(
        worldId,
        null, // Session Zero: no location assigned
        [],
      );

      // Should return null since no recency matches and no current location
      expect(result, isNull);
    });

    test('includes species context when provided', () async {
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      await dao.createLocationFromValues(
        worldId: worldId,
        name: 'Test Location',
        description: 'A test',
        type: 'Test',
      );

      final result = await contextService.buildRelevantWorldData(
        worldId,
        null,
        [
          ChatMessage(
            id: 1,
            role: MessageRole.user,
            content: 'Going to Test Location',
            timestamp: DateTime.now(),
            worldId: worldId,
            characterId: 1,
          ),
        ],
        speciesContext: '[VALID SPECIES]\nHuman, Elf, Dwarf',
      );

      expect(result, isNotNull);
      expect(result, contains('[VALID SPECIES]'));
      expect(result, contains('Human, Elf, Dwarf'));
    });

    test('returns only species context when no locations/npcs match', () async {
      final worldId = await dao.createWorld(WorldsCompanion.insert(
        name: 'Empty World',
        genre: 'Fantasy',
        description: 'A test world',
      ));

      final result = await contextService.buildRelevantWorldData(
        worldId,
        null,
        [],
        speciesContext: '[VALID SPECIES]\nHuman',
      );

      expect(result, equals('[VALID SPECIES]\nHuman'));
    });
  });
}
