import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
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
