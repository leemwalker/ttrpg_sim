import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';

final _db = AppDatabase();

final databaseProvider = Provider<AppDatabase>((ref) {
  return _db;
});

final gameDaoProvider = Provider<GameDao>((ref) {
  final db = ref.watch(databaseProvider);
  return GameDao(db);
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("GEMINI_API_KEY not found");
  }
  return GeminiService(apiKey);
});

final characterDataProvider =
    FutureProvider.family<CharacterData?, int>((ref, worldId) async {
  final dao = ref.watch(gameDaoProvider);
  final db = ref.watch(databaseProvider);
  print('🔮 FUTURE using DB Instance: ${db.instanceId} for World: $worldId');
  print('🔮 FUTURE: Fetching fresh character data...');
  final char = await dao.getCharacter(worldId);
  print('🔮 FUTURE RESULT: HP ${char?.currentHp}');
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
