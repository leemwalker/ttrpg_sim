import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/database/database.dart';

const String systemInstruction = """
You are a Dungeon Master for a solo D&D 5e campaign.
1. **Rules:** Adhere strictly to the D&D 5.1 SRD.
2. **Output Format:** You must ALWAYS return valid JSON.
3. **Schema:**
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
4. **Style:** Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
""";

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
  final GenerativeModel _model;

  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
          systemInstruction: Content.system(systemInstruction),
        );

  Future<TurnResult> sendMessage(String userMessage, GameDao dao) async {
    // Step 1: Fetch Context
    final character = await dao.getCharacter();
    final inventory = await dao.getInventory();

    // Step 2: Format Context
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

    // Step 3: Interpolate Prompt
    final prompt = """
$contextSummary

User Action: $userMessage
""";

    // Send to model
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    final text = response.text;
    if (text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return TurnResult.fromJson(json);
    } catch (e) {
      throw Exception(
          'Failed to parse Gemini response: $e\nResponse text: $text');
    }
  }
}
