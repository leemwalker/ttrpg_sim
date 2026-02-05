import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/features/game/services/context_service.dart';

class BenchmarkService {
  final ContextService _contextService;
  final GameDao _dao;

  BenchmarkService(this._contextService, this._dao);

  Future<String> measureContextLoad(int worldId, int? characterId) async {
    final stopwatch = Stopwatch()..start();

    // We need to fetch recent chat to pass to the context service,
    // just like GameController does.
    List<ChatMessage> recentChat = [];
    int? locationId;
    String speciesContext = ""; // Simplified for benchmark

    if (characterId != null) {
      recentChat = await _dao.getRecentMessages(characterId, 6);
      final char = await _dao.getCharacterById(characterId);
      locationId = char?.currentLocationId;
    }

    final result = await _contextService.buildRelevantWorldData(
      worldId,
      locationId,
      recentChat,
      speciesContext: speciesContext,
    );

    stopwatch.stop();

    final messageCount = recentChat.length;
    final contextLength = result?.length ?? 0;

    return "Context Build Time: ${stopwatch.elapsedMilliseconds}ms\n"
        "Messages Scanned: $messageCount\n"
        "Context Length: $contextLength chars";
  }
}
