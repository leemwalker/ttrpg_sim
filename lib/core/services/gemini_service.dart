import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/database/database.dart';

// Static instruction removed in favor of dynamic generation

class TurnResult {
  final String narrative;
  final Map<String, dynamic> stateUpdates;

  TurnResult({required this.narrative, required this.stateUpdates});

  // Factory constructor to parse the JSON string from Gemini
  factory TurnResult.fromJson(Map<String, dynamic> json) {
    return TurnResult(
      narrative: json['narrative'] as String,
      stateUpdates: json['state_updates'] as Map<String, dynamic>,
    );
  }
}

class GeminiService {
  final String _apiKey;
  ChatSession? _currentSession;
  int? _currentWorldId;
  // Track player state to detect changes requiring session refresh
  String? _lastPlayerClass;
  int? _lastPlayerLevel;

  GeminiService(this._apiKey);

  String _buildInstruction(
      String genre, String description, CharacterData player) {
    return """
You are a Game Master running a $genre tabletop RPG.
World Context: $description.

Player Profile:
- Name: ${player.name}
- Class: ${player.heroClass} (Level ${player.level})
- Species: ${player.species}
- Max HP: ${player.maxHp}

Rules:
1. Adhere strictly to the D&D 5.1 SRD.
2. If the player tries to use a class ability (like spells), verify if a Level ${player.level} ${player.heroClass} would realistically know it.
3. Output Format: You must ALWAYS return valid JSON.
4. Schema:
{
  "narrative": "The story description and dialogue goes here.",
  "state_updates": {
    "hp_change": 0, 
    "gold_change": 0, 
    "add_items": [], 
    "remove_items": [], 
    "location_update": null
  }
}
5. Style: Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
""";
  }

  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String description,
    required CharacterData player,
  }) async {
    // Check if session needs refresh (world changed OR player class/level changed)
    final needsRefresh = _currentSession == null ||
        _currentWorldId != worldId ||
        _lastPlayerClass != player.heroClass ||
        _lastPlayerLevel != player.level;

    if (needsRefresh) {
      print(
          '🧠 GEMINI: Initializing new session for World $worldId (${player.name} the ${player.heroClass})');
      final instruction = _buildInstruction(genre, description, player);
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        systemInstruction: Content.system(instruction),
      );
      _currentSession = model.startChat();
      _currentWorldId = worldId;
      _lastPlayerClass = player.heroClass;
      _lastPlayerLevel = player.level;
    } else {
      print('🧠 GEMINI: Reusing existing session for World $worldId');
    }

    // Fetch Context (inventory)
    final inventory = await dao.getInventoryForCharacter(player.id);

    // Format Context
    String contextSummary = "Current Status: ";
    contextSummary += "HP ${player.currentHp}/${player.maxHp}, ";
    contextSummary += "Location: ${player.location}, ";
    contextSummary += "Gold: ${player.gold}";

    contextSummary += "\nInventory: ";
    if (inventory.isNotEmpty) {
      contextSummary +=
          inventory.map((e) => "${e.itemName} (x${e.quantity})").join(', ');
    } else {
      contextSummary += "Empty";
    }

    // Interpolate Prompt
    final prompt = """
$contextSummary

User Action: $userMessage
""";

    // Send to model
    print(
        'DEBUG: Sending request to model: gemini-flash-latest with key starting: ${_apiKey.substring(0, 5)}...');

    // Using sendMessage on the chat session maintains history
    final response = await _currentSession!.sendMessage(Content.text(prompt));

    print('🔍 RAW GEMINI RESPONSE: ${response.text}');

    final text = response.text;
    if (text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      return TurnResult.fromJson(json);
    } catch (e) {
      throw Exception(
          'Failed to parse Gemini response: $e\nResponse text: $text');
    }
  }
}
