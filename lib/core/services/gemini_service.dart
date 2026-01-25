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

  GeminiService(this._apiKey);

  String _buildInstruction(String genre, String description) {
    return """
You are a Game Master running a $genre tabletop RPG.
World Context: $description.

Rules:
1. Adhere strictly to the D&D 5.1 SRD.
2. Output Format: You must ALWAYS return valid JSON.
3. Schema:
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
4. Style: Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
""";
  }

  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String description,
  }) async {
    // Step 1: Initialize Session if needed
    if (_currentSession == null || _currentWorldId != worldId) {
      print('🧠 GEMINI: Initializing new session for World $worldId ($genre)');
      final instruction = _buildInstruction(genre, description);
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
    } else {
      print('🧠 GEMINI: Reusing existing session for World $worldId');
    }

    // Step 2: Fetch Context
    final character = await dao.getCharacter(worldId);
    final inventory = await dao.getInventoryForCharacter(character?.id ?? -1);

    // Step 3: Format Context
    String contextSummary = "Current Status: ";
    if (character != null) {
      contextSummary += "HP ${character.currentHp}/${character.maxHp}, ";
      contextSummary += "Location: ${character.location}, ";
      contextSummary += "Gold: ${character.gold}";
    } else {
      contextSummary += "Character not found.";
    }

    contextSummary += "\nInventory: ";
    if (inventory.isNotEmpty) {
      contextSummary +=
          inventory.map((e) => "${e.itemName} (x${e.quantity})").join(', ');
    } else {
      contextSummary += "Empty";
    }

    // Step 4: Interpolate Prompt
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
