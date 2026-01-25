import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class MockGeminiService implements GeminiService {
  final Map<String, dynamic> nextStateUpdates;
  final String nextNarrative;
  final FunctionCall? nextFunctionCall;

  MockGeminiService({
    this.nextStateUpdates = const {},
    this.nextNarrative = "Mock Narrative",
    this.nextFunctionCall,
  });

  @override
  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String description,
    required CharacterData player,
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
  }) async {
    return TurnResult(
      narrative: nextNarrative,
      stateUpdates: nextStateUpdates,
      functionCall: nextFunctionCall,
    );
  }

  @override
  Future<TurnResult> sendFunctionResponse(
    String functionName,
    Map<String, dynamic> response,
  ) async {
    return TurnResult(
      narrative: nextNarrative,
      stateUpdates: nextStateUpdates,
      functionCall: nextFunctionCall,
    );
  }
}
