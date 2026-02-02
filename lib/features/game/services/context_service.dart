import 'package:ttrpg_sim/core/database/database.dart';

/// Service for filtering world context to keep AI prompts lightweight.
///
/// Only injects Locations and NPCs that are relevant to the current scene,
/// preventing prompt bloat as the world grows.
class ContextService {
  final GameDao _dao;

  ContextService(this._dao);

  /// Builds a filtered [PERSISTENT WORLD DATA] string with only relevant items.
  ///
  /// Filtering Logic:
  /// 1. **Mandatory**: Current location + NPCs at that location
  /// 2. **Recency**: NPCs/Locations mentioned in recent chat (last 3 turn pairs)
  /// 3. **Pinned**: (Future) Party members, quest givers, etc.
  ///
  /// Returns `null` if no relevant data exists.
  Future<String?> buildRelevantWorldData(
    int worldId,
    int? locationId,
    List<ChatMessage> recentChat, {
    String? speciesContext,
  }) async {
    // Collect relevant items
    final relevantLocations = <Location>{};
    final relevantNpcs = <Npc>{};

    // Fetch all world data for filtering
    final allLocations = await _dao.getLocationsForWorld(worldId);
    final allNpcs = await _dao.getNpcsForWorld(worldId);

    // --- STEP 1: Current Location (Mandatory) ---
    if (locationId != null) {
      final currentLocation =
          allLocations.where((l) => l.id == locationId).firstOrNull;
      if (currentLocation != null) {
        relevantLocations.add(currentLocation);
      }

      // NPCs at current location
      final npcsAtLocation =
          allNpcs.where((n) => n.locationId == locationId).toList();
      relevantNpcs.addAll(npcsAtLocation);
    }

    // --- STEP 2: Recency Filter (Last 3 Turn Pairs = 6 messages) ---
    // Combine recent chat content for matching
    final recentText =
        recentChat.take(6).map((m) => m.content.toLowerCase()).join(' ');

    // Check each NPC name against recent chat
    // Note: Simple .contains() may have false positives (e.g., "Al" in "also")
    // Can upgrade to word boundary regex later if needed: RegExp(r'\b' + name + r'\b')
    for (final npc in allNpcs) {
      if (recentText.contains(npc.name.toLowerCase())) {
        relevantNpcs.add(npc);
      }
    }

    // Check each Location name against recent chat
    for (final location in allLocations) {
      if (recentText.contains(location.name.toLowerCase())) {
        relevantLocations.add(location);
      }
    }

    // --- STEP 3: Pinned Items (Future) ---
    // TODO: Add support for Party Members, Quest Givers, or isPinned flag
    // Example: relevantNpcs.addAll(allNpcs.where((n) => n.role == 'Party Member'));

    // --- Build Output ---
    if (relevantLocations.isEmpty && relevantNpcs.isEmpty) {
      // Still include species context if available
      return speciesContext?.isNotEmpty == true ? speciesContext : null;
    }

    final buffer = StringBuffer();
    buffer.writeln('[PERSISTENT WORLD DATA]');
    buffer.writeln(
        'The following locations and NPCs are relevant to the current scene. Use these details to maintain consistency:');

    if (relevantLocations.isNotEmpty) {
      buffer.write('Locations: ');
      buffer.writeln(relevantLocations
          .map((l) => '${l.name}: ${l.description}')
          .join('; '));
    }

    if (relevantNpcs.isNotEmpty) {
      buffer.write('NPCs: ');
      buffer.writeln(relevantNpcs
          .map((n) =>
              '${n.name}: ${n.role}${n.history != null ? " [History: ${n.history}]" : ""}')
          .join('; '));
    }

    if (speciesContext?.isNotEmpty == true) {
      buffer.writeln(speciesContext);
    }

    return buffer.toString();
  }
}
