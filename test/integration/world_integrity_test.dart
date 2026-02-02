import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/features/game/services/world_service.dart';

/// Integration tests for World Integrity System (Task 2)
void main() {
  late AppDatabase db;
  late GameDao dao;
  late WorldService worldService;
  late int testWorldId;

  setUp(() async {
    // Use in-memory database for testing
    db = AppDatabase(NativeDatabase.memory());
    dao = db.gameDao;
    worldService = WorldService(dao);

    // Create a test world using companion
    testWorldId = await dao.createWorld(WorldsCompanion(
      name: const Value('Test World'),
      genre: const Value('Fantasy'),
      description: const Value('A test world for integrity testing'),
      tone: const Value('Standard'),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('World Integrity System', () {
    test('discoverPoI creates unvisited location', () async {
      // When: We discover a new POI via NPC mention
      final locationId = await worldService.discoverPoI(
        name: 'The Forgotten Temple',
        worldId: testWorldId,
        description: 'A mysterious temple mentioned by a traveler',
        type: 'Dungeon',
      );

      // Then: Location is created with isVisited = false
      final location = await dao.getLocation(locationId);
      expect(location, isNotNull);
      expect(location!.name, 'The Forgotten Temple');
      expect(location.isVisited, false);
      expect(location.history, isNull);
    });

    test('visitLocation marks location as visited', () async {
      // Given: An unvisited location
      final locationId = await worldService.discoverPoI(
        name: 'The Lost City',
        worldId: testWorldId,
      );

      var location = await dao.getLocation(locationId);
      expect(location!.isVisited, false);

      // When: Player visits the location
      await worldService.visitLocation(locationId);

      // Then: isVisited is now true
      location = await dao.getLocation(locationId);
      expect(location!.isVisited, true);
    });

    test('addLocationHistory appends events', () async {
      // Given: A location
      final locationId = await worldService.discoverPoI(
        name: 'Dragon\'s Lair',
        worldId: testWorldId,
      );

      // When: We add history events
      await worldService.addLocationHistory(
        locationId: locationId,
        eventSummary: 'Player discovered the entrance',
      );
      await worldService.addLocationHistory(
        locationId: locationId,
        eventSummary: 'Player defeated the dragon',
      );

      // Then: History contains both events
      final history = await worldService.getLocationHistory(locationId);
      expect(history.length, 2);
      expect(history[0], 'Player discovered the entrance');
      expect(history[1], 'Player defeated the dragon');
    });

    test('updateNpcMemory tracks player interactions', () async {
      // Given: An NPC in the world
      final locationId = await worldService.discoverPoI(
        name: 'Village Inn',
        worldId: testWorldId,
      );
      final npcId = await dao.createNpcFromValues(
        worldId: testWorldId,
        locationId: locationId,
        name: 'Old Sage',
        role: 'Advisor',
        description: 'A wise old man who knows many secrets',
      );

      // When: Player interacts with NPC
      await worldService.updateNpcMemory(
        npcId: npcId,
        interaction: 'Player asked about the nearby dungeon',
      );
      await worldService.updateNpcMemory(
        npcId: npcId,
        interaction: 'Player traded some gold for advice',
        mentionedPoI: 'Hidden Cave',
      );

      // Then: NPC memory is updated
      final memory = await worldService.getNpcMemory(npcId);
      expect(memory['player_interactions'], hasLength(2));
      expect(memory['mentioned_pois'], contains('Hidden Cave'));
    });

    test('NPC memory deduplicates mentioned POIs', () async {
      // Given: A location first
      final locationId = await worldService.discoverPoI(
        name: 'Market Square',
        worldId: testWorldId,
      );

      // Create NPC with valid location
      final npcId = await dao.createNpcFromValues(
        worldId: testWorldId,
        locationId: locationId,
        name: 'Wanderer',
        role: 'Traveling Merchant',
        description: 'A merchant who has seen many places',
      );

      // When: Same POI is mentioned multiple times
      await worldService.updateNpcMemory(
          npcId: npcId, mentionedPoI: 'Ancient Ruins');
      await worldService.updateNpcMemory(
          npcId: npcId, mentionedPoI: 'Ancient Ruins');
      await worldService.updateNpcMemory(
          npcId: npcId, mentionedPoI: 'Mystic Forest');

      // Then: POI list is deduplicated
      final memory = await worldService.getNpcMemory(npcId);
      expect(memory['mentioned_pois'], hasLength(2));
      expect(memory['mentioned_pois'],
          containsAll(['Ancient Ruins', 'Mystic Forest']));
    });
  });
}
