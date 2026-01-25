import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Use custom key if present, otherwise fallback to .env or const (as per request)
  // Request says: "Fallback to const String.fromEnvironment('GEMINI_API_KEY')"
  // But previously we used dotenv. Let's stick to dotenv for now as it's set up in main.
  // Wait, user explicitly said: "Fallback to const String.fromEnvironment('GEMINI_API_KEY')".
  // I should strictly follow that if they want compile-time constant, OR maybe they meant the dotenv variable?
  // The existing code used `dotenv.env['GEMINI_API_KEY']`.
  // The user prompt says: "If not, fallback to const String.fromEnvironment('GEMINI_API_KEY')."
  // Note: String.fromEnvironment is for --dart-define. dotenv is for .env files.
  // I will check if the user really wants fromEnvironment (compile time) or if they meant the existing dotenv.
  // Given "Task 3... Fallback to const String.fromEnvironment...", I'll implement what they asked,
  // BUT I should also keep dotenv as a fallback if fromEnvironment is empty, or just use dotenv if they are confused.
  // However, `dotenv` was used in `main.dart` load.
  // I'll combine them: use settings -> fromEnvironment -> dotenv to be safe?
  // Or just follow instructions literally.
  // Literall instruction: "If not, fallback to const String.fromEnvironment('GEMINI_API_KEY')."
  // Since I am an expert, I know `String.fromEnvironment` is often used for secrets in build.
  // But the project uses `flutter_dotenv`.
  // I will use: settings.apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '')
  // AND if that is empty, try dotenv?
  // Actually, let's look at the existing code:
  /*
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) { ... }
  */
  // I'll try to support both to be helpful.

  String apiKey = settings.apiKey ?? '';
  if (apiKey.isEmpty) {
    apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  }
  if (apiKey.isEmpty) {
    apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  if (apiKey.isEmpty) {
    throw Exception(
        "GEMINI_API_KEY not found in Settings, Environment, or .env");
  }

  return GeminiService(apiKey, modelName: settings.modelName);
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

final locationDataProvider =
    FutureProvider.family<Location?, int?>((ref, id) async {
  if (id == null) return null;
  final dao = ref.watch(gameDaoProvider);
  return dao.getLocation(id);
});
