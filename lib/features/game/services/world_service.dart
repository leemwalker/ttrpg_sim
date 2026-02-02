import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ttrpg_sim/core/database/database.dart';

/// Service for managing World Integrity - location discovery, visitation, and NPC memory.
class WorldService {
  final GameDao _dao;

  WorldService(this._dao);

  /// Creates a new Location entry with isVisited: false.
  /// Used when an NPC or narrative mentions a location that doesn't exist yet.
  /// Returns the ID of the created location.
  Future<int> discoverPoI({
    required String name,
    required int worldId,
    String description = 'An undiscovered location.',
    String type = 'Unknown',
  }) async {
    final companion = LocationsCompanion(
      name: Value(name),
      worldId: Value(worldId),
      description: Value(description),
      type: Value(type),
      isVisited: const Value(false),
    );
    return await _dao.createLocation(companion);
  }

  /// Marks a location as visited.
  /// Sets isVisited: true when the player actually visits the location.
  Future<void> visitLocation(int locationId) async {
    await _dao.updateLocationVisited(locationId, true);
  }

  /// Appends an interaction to the NPC's memory JSON.
  /// Memory format: { "player_interactions": ["..."], "mentioned_pois": ["..."] }
  Future<void> updateNpcMemory({
    required int npcId,
    String? interaction,
    String? mentionedPoI,
  }) async {
    // Get current NPC
    final npc = await _dao.getNpc(npcId);
    if (npc == null) return;

    // Parse existing memory or create new structure
    Map<String, dynamic> memory;
    try {
      memory = npc.memory != null
          ? jsonDecode(npc.memory!) as Map<String, dynamic>
          : {'player_interactions': [], 'mentioned_pois': []};
    } catch (e) {
      memory = {'player_interactions': [], 'mentioned_pois': []};
    }

    // Append new data
    if (interaction != null) {
      final interactions =
          List<String>.from(memory['player_interactions'] ?? []);
      interactions.add(interaction);
      memory['player_interactions'] = interactions;
    }

    if (mentionedPoI != null) {
      final pois = List<String>.from(memory['mentioned_pois'] ?? []);
      if (!pois.contains(mentionedPoI)) {
        pois.add(mentionedPoI);
      }
      memory['mentioned_pois'] = pois;
    }

    // Save updated memory
    await _dao.updateNpcMemory(npcId, jsonEncode(memory));
  }

  /// Appends an event summary to the location's history JSON.
  /// History format: ["Event 1 summary", "Event 2 summary", ...]
  Future<void> addLocationHistory({
    required int locationId,
    required String eventSummary,
  }) async {
    final location = await _dao.getLocation(locationId);
    if (location == null) return;

    // Parse existing history or create new list
    List<String> history;
    try {
      history = location.history != null
          ? List<String>.from(jsonDecode(location.history!) as List)
          : [];
    } catch (e) {
      history = [];
    }

    // Append new event
    history.add(eventSummary);

    // Save updated history
    await _dao.updateLocationHistory(locationId, jsonEncode(history));
  }

  /// Get full history for a location (for context injection)
  Future<List<String>> getLocationHistory(int locationId) async {
    final location = await _dao.getLocation(locationId);
    if (location == null || location.history == null) return [];

    try {
      return List<String>.from(jsonDecode(location.history!) as List);
    } catch (e) {
      return [];
    }
  }

  /// Get NPC memory (for context injection)
  Future<Map<String, dynamic>> getNpcMemory(int npcId) async {
    final npc = await _dao.getNpc(npcId);
    if (npc == null || npc.memory == null) {
      return {'player_interactions': [], 'mentioned_pois': []};
    }

    try {
      return jsonDecode(npc.memory!) as Map<String, dynamic>;
    } catch (e) {
      return {'player_interactions': [], 'mentioned_pois': []};
    }
  }
}
