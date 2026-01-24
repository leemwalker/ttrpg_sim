import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/campaign/data/models/character.dart';
import '../../features/campaign/data/models/location.dart';
import '../../features/campaign/data/models/inventory_item.dart';

/// Container for the full game state to be passed to the LLM.
class GameState {
  final Character character;
  final Location currentLocation;
  final List<InventoryItem> inventory;
  final List<Map<String, dynamic>> recentHistory;

  GameState({
    required this.character,
    required this.currentLocation,
    required this.inventory,
    required this.recentHistory,
  });

  Map<String, dynamic> toJson() => {
    'character': character.toJson(),
    'currentLocation': currentLocation.toJson(),
    'inventory': inventory.map((e) => e.toJson()).toList(),
    'recentHistory': recentHistory,
  };
}

/// Response from the AI containing both narrative and state updates.
class AiResponse {
  final String narrative;
  final Map<String, dynamic>? stateUpdates;

  AiResponse({required this.narrative, this.stateUpdates});
}

class AiService {
  final GenerativeModel _model;

  AiService({required String apiKey})
      : _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

  Future<AiResponse> sendMessage(String userText, GameState currentState) async {
    final stateJson = jsonEncode(currentState.toJson());
    
    final prompt = '''
You are a Dungeon Master for a TTRPG based on the D&D 5.1 SRD.
Do not use any Product Identity (e.g., Beholders, Mind Flayers).

Current Game State:
$stateJson

User Action:
$userText

Instructions:
1. Narrate the result of the user's action.
2. If the game state changes (HP, inventory, location, etc.), provide a strictly valid JSON object representing the *changes* only in a specific block.

Output Format:
Return your response in a JSON block like this (no markdown code fences around the whole thing, just the raw JSON or a JSON block):

```json
{
  "narrative": "The goblin sneers and lunges...",
  "state_updates": {
    "character": { "hp": 12 },
    "inventory_add": [],
    "inventory_remove": []
  }
}
```
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    final responseText = response.text;

    if (responseText == null) {
      throw Exception('Empty response from AI');
    }

    try {
      // Attempt to parse the whole response as JSON if the model complied perfectly
      // Or extract JSON from code blocks if it wrapped it.
      String jsonString = responseText;
      final jsonBlockRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
      final match = jsonBlockRegex.firstMatch(responseText);
      
      if (match != null) {
        jsonString = match.group(1)!;
      }

      final parsed = jsonDecode(jsonString);
      return AiResponse(
        narrative: parsed['narrative'] ?? responseText,
        stateUpdates: parsed['state_updates'],
      );
    } catch (e) {
      // Fallback: Model failed to output rigid JSON, return raw text as narrative.
      return AiResponse(narrative: responseText, stateUpdates: null);
    }
  }
}
