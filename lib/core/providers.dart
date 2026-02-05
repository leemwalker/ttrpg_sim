import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/settings/settings_provider.dart';
import 'package:ttrpg_sim/features/character/services/progression_service.dart';
import 'package:ttrpg_sim/core/services/story_generator_service.dart';
import 'package:ttrpg_sim/core/services/pdf_export_service.dart';
import 'package:ttrpg_sim/features/developer/services/stress_test_service.dart';
import 'package:ttrpg_sim/features/developer/services/benchmark_service.dart';
import 'package:ttrpg_sim/features/game/services/context_service.dart';

final _db = AppDatabase();

final databaseProvider = Provider<AppDatabase>((ref) {
  return _db;
});

final gameDaoProvider = Provider<GameDao>((ref) {
  final db = ref.watch(databaseProvider);
  return GameDao(db);
});

final progressionServiceProvider = Provider<ProgressionService>((ref) {
  final dao = ref.watch(gameDaoProvider);
  return ProgressionService(dao);
});

final stressTestServiceProvider = Provider<StressTestService>((ref) {
  final dao = ref.read(gameDaoProvider);
  return StressTestService(dao);
});

final benchmarkServiceProvider = Provider<BenchmarkService>((ref) {
  final dao = ref.read(gameDaoProvider);
  // ContextService is not currently a provider, we instantiate it manually or we should make it one.
  // GameController instantiates it manually: final contextService = ContextService(dao);
  // We can do the same here.
  final contextService = ContextService(dao);
  return BenchmarkService(contextService, dao);
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

final worldProvider = FutureProvider.family<World?, int>((ref, id) async {
  final dao = ref.watch(gameDaoProvider);
  return dao.getWorld(id);
});

final locationDataProvider =
    FutureProvider.family<Location?, int?>((ref, id) async {
  if (id == null) return null;
  final dao = ref.watch(gameDaoProvider);
  return dao.getLocation(id);
});

final storyGeneratorServiceProvider = Provider<StoryGeneratorService>((ref) {
  final gemini = ref.watch(geminiServiceProvider);
  final dao = ref.watch(gameDaoProvider);
  final settings = ref.watch(settingsProvider);

  return StoryGeneratorService(
    gemini,
    dao,
    ghostwritingModel: settings.ghostwritingModel,
    paidApiKey: settings.paidApiKey,
  );
});

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService();
});
