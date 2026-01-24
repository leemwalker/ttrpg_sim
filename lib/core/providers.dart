import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  return GeminiService();
});
