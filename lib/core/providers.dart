import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/settings/settings_provider.dart';

final _db = AppDatabase();

final databaseProvider = Provider<AppDatabase>((ref) {
  return _db;
});

final gameDaoProvider = Provider<GameDao>((ref) {
  final db = ref.watch(databaseProvider);
  return GameDao(db);
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final settings = ref.watch(settingsProvider);

  final apiKey = settings.apiKey ?? '';

  if (apiKey.isEmpty) {
    throw Exception(
        "No API key configured. Please go to Settings and enter your Gemini API Key.");
  }

  return GeminiService(apiKey, modelName: settings.modelName);
});

final characterDataProvider =
    FutureProvider.family<CharacterData?, int>((ref, worldId) async {
  final dao = ref.watch(gameDaoProvider);
  // final db = ref.watch(databaseProvider);
  // Log Removed
  // Log Removed
  final char = await dao.getCharacter(worldId);
  // Log Removed
  return char;
});

final inventoryDataProvider =
    FutureProvider.family<List<InventoryData>, int>((ref, charId) async {
  final dao = ref.watch(gameDaoProvider);
  return dao.getInventoryForCharacter(charId);
});

final worldsProvider = FutureProvider<List<World>>((ref) async {
  final dao = ref.watch(gameDaoProvider);
  return dao.getAllWorlds();
});

final locationDataProvider =
    FutureProvider.family<Location?, int?>((ref, id) async {
  if (id == null) return null;
  final dao = ref.watch(gameDaoProvider);
  return dao.getLocation(id);
});
