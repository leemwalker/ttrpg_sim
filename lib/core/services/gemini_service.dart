import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';

// Static instruction removed in favor of dynamic generation

class TurnResult {
  final String narrative;
  final Map<String, dynamic> stateUpdates;
  final FunctionCall? functionCall;

  TurnResult({
    required this.narrative,
    required this.stateUpdates,
    this.functionCall,
  });

  // Factory constructor to parse the JSON string from Gemini
  factory TurnResult.fromJson(Map<String, dynamic> json,
      {FunctionCall? functionCall}) {
    return TurnResult(
      narrative: json['narrative'] as String,
      stateUpdates: json['state_updates'] as Map<String, dynamic>,
      functionCall: functionCall,
    );
  }
}

class GeminiService {
  final String _apiKey;
  final String _modelName;
  ChatSessionWrapper? _currentSession;
  int? _currentWorldId;
  // Track player state to detect changes requiring session refresh
  String? _lastPlayerClass;
  int? _lastPlayerLevel;

  GeminiService(this._apiKey, {String modelName = 'gemini-1.5-flash'})
      : _modelName = modelName;

  /// Factory method to create the model (wrapped)
  GenerativeModelWrapper createModel(String instruction) {
    final realModel = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(instruction),
      tools: [locationTool, diceTool],
    );
    return GoogleGenerativeModelWrapper(realModel);
  }

  /// Tool definition for location generation
  static final Tool locationTool = Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'generate_location',
        'Generate a new location with POIs and NPCs when the player enters or describes a new area. Call this when the player describes where they want to start or when they travel to a new place.',
        Schema.object(
          properties: {
            'name': Schema.string(description: 'Name of the location'),
            'description':
                Schema.string(description: 'Vivid description of the location'),
            'type': Schema.enumString(
              enumValues: [
                'Village',
                'Town',
                'City',
                'Dungeon',
                'Wilderness',
                'Cave',
                'Castle',
                'Tavern'
              ],
              description: 'Type of location',
            ),
            'pois': Schema.array(
              items: Schema.object(
                properties: {
                  'name': Schema.string(description: 'Name of the POI'),
                  'type': Schema.string(
                      description: 'Type like Shop, Tavern, Temple, etc.'),
                  'description':
                      Schema.string(description: 'Brief description'),
                },
              ),
              description: 'Points of interest at this location',
              nullable: true,
            ),
            'npcs': Schema.array(
              items: Schema.object(
                properties: {
                  'name': Schema.string(description: 'NPC name'),
                  'role': Schema.string(
                      description: 'Role like Innkeeper, Guard, Merchant'),
                  'description':
                      Schema.string(description: 'Brief description'),
                },
              ),
              description: 'NPCs present at this location',
              nullable: true,
            ),
          },
          requiredProperties: ['name', 'description', 'type'],
        ),
      ),
    ],
  );

  /// Tool definition for dice rolls
  static final Tool diceTool = Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'roll_check',
        'Request a skill or ability check from the player. Call this when the player attempts an action that requires a dice roll.',
        Schema.object(
          properties: {
            'check_name': Schema.string(
              description:
                  'The name of the skill (e.g., "Stealth", "Perception") or ability (e.g., "strength", "dexterity") to check.',
            ),
            'difficulty': Schema.integer(
              description:
                  'The Difficulty Class (DC) that must be met or exceeded for success.',
            ),
          },
          requiredProperties: ['check_name', 'difficulty'],
        ),
      ),
    ],
  );

  String _buildInstruction(
    String genre,
    String tone,
    String description,
    CharacterData player, {
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    required List<InventoryData> items,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
  }) {
    final featuresStr = features.isNotEmpty ? features.join(', ') : 'None';
    final slotsStr = spellSlots.isNotEmpty ? spellSlots.toString() : 'None';
    final spellsStr = spells.isNotEmpty ? spells.join(', ') : 'None';
    final itemsStr = items.isNotEmpty
        ? items.map((e) => '${e.itemName} (x${e.quantity})').join(', ')
        : 'None';

    // Build location context based on Genesis Mode vs Atlas Mode
    String locationContext;
    if (location == null) {
      // Genesis Mode: Session Zero - ask player where to start
      locationContext = """
CURRENT STATUS:
- Player: ${player.name} (${player.heroClass} Level ${player.level})
- Location: Unspecified / Session Zero

MISSION:
The World: $genre setting. Tone: $tone. $description.
The Player: ${player.name}.
Background: ${player.background}.
Backstory: ${player.backstory}.

Goal: Conduct a 'Session Zero'.
1. Welcome the player to the table using a tone appropriate for a $tone setting.
2. Briefly summarize how their character might fit into this world based on their backstory.
3. Ask the player 1 or 2 probing questions to flesh out their connections or motivations (e.g., 'Who is your rival?', 'Why did you leave home?').
4. Do NOT start the adventure yet. We are establishing the scene. Ask them to confirm if this fits their vision or if they want to adjust anything.
""";
    } else {
      // Atlas Mode: Describe current location with POIs and NPCs
      final poisStr =
          pois.isEmpty ? 'None visible' : pois.map((p) => p.name).join(', ');
      final npcsStr = npcs.isEmpty
          ? 'None visible'
          : npcs.map((n) => '${n.name} (${n.role})').join(', ');
      locationContext = """
CURRENT LOCATION:
- Name: ${location.name}
- Description: ${location.description}
- Points of Interest: $poisStr
- Visible NPCs: $npcsStr""";
    }

    return """
You are a Game Master running a $genre tabletop RPG.
Tone: $tone.
World Context: $description.

Player Profile:
- Name: ${player.name}
- Class: ${player.heroClass} (Level ${player.level})
- Species: ${player.species}
- Background: ${player.background ?? 'Unknown'}
- Max HP: ${player.maxHp}

ABILITIES & LIMITS:
- Class Features: $featuresStr
- Max Spell Slots: $slotsStr
- Known Spells/Cantrips: $spellsStr
- Inventory: $itemsStr

$locationContext

Rules:
1. Adhere strictly to the D&D 5.1 SRD.
2. If the player attempts to cast a spell NOT in their Known Spells, or of a level higher than they have slots for, reject the action and narrate the failure gracefully.
3. If the player tries to use a class feature NOT in their Class Features, narrate why they cannot do that yet.
4. Output Format: You must ALWAYS return valid JSON.
5. Schema:
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
6. Style: Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
""";
  }

  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String tone,
    required String description,
    required CharacterData player,
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
  }) async {
    // Fetch inventory first (needed for both session init and context)
    final inventory = await dao.getInventoryForCharacter(player.id);

    // Check if session needs refresh (world changed OR player class/level changed)
    final needsRefresh = _currentSession == null ||
        _currentWorldId != worldId ||
        _lastPlayerClass != player.heroClass ||
        _lastPlayerLevel != player.level;

    if (needsRefresh) {
      // Log Removed
      final instruction = _buildInstruction(
        genre,
        tone,
        description,
        player,
        features: features,
        spellSlots: spellSlots,
        spells: spells,
        items: inventory,
        location: location,
        pois: pois,
        npcs: npcs,
      );
      final model = createModel(instruction);
      _currentSession = model.startChat();
      _currentWorldId = worldId;
      _lastPlayerClass = player.heroClass;
      _lastPlayerLevel = player.level;
    } else {
      // Log Removed
    }

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
    // Log Removed

    GenerateContentResponse response;
    try {
      // Using sendMessage on the chat session maintains history
      response = await _currentSession!.sendMessage(Content.text(prompt));
    } on GenerativeAIException catch (e) {
      if (e.toString().contains('403') ||
          e.toString().toLowerCase().contains('api key')) {
        throw ApiKeyException('Invalid API Key provided', e);
      }
      throw AppBaseException('AI Service Error', e);
    } on SocketException catch (e) {
      throw NetworkException('No internet connection', e);
    } catch (e) {
      throw AppBaseException('Unexpected error communicating with AI', e);
    }

    // Check for function calls first
    final functionCalls = response.functionCalls.toList();
    if (functionCalls.isNotEmpty) {
      final fc = functionCalls.first;
      // print('🔧 GEMINI FUNCTION CALL: ${fc.name} with args: ${fc.args}');
      // Return a TurnResult with the function call but empty narrative/updates
      // The controller will handle the function call and may re-prompt for narrative
      return TurnResult(
        narrative:
            '', // Will be populated after controller handles the function
        stateUpdates: {},
        functionCall: fc,
      );
    }

    // print('🔍 RAW GEMINI RESPONSE: ${response.text}');

    final text = response.text;
    if (text == null) {
      throw AIFormatException('Empty response from AI engine');
    }

    try {
      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      return TurnResult.fromJson(json);
    } catch (e) {
      throw AIFormatException(
          'Failed to parse Gemini response: $e\nResponse text: $text', e);
    }
  }

  /// Send a function response back to the model and get the narrative result.
  Future<TurnResult> sendFunctionResponse(
    String functionName,
    Map<String, dynamic> response,
  ) async {
    if (_currentSession == null) {
      throw Exception('No active session to send function response to');
    }

    // print('📤 SENDING FUNCTION RESPONSE: $functionName -> $response');

    try {
      final functionResponse = Content.functionResponse(functionName, response);
      final result = await _currentSession!.sendMessage(functionResponse);

      // print('🔍 RAW GEMINI RESPONSE (Post-Function): ${result.text}');

      // Parse the text response as JSON
      final text = result.text;
      if (text == null) {
        throw AIFormatException('No response from Gemini after function call');
      }

      try {
        final cleanJson =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        final json = jsonDecode(cleanJson) as Map<String, dynamic>;
        return TurnResult.fromJson(json);
      } catch (e) {
        throw AIFormatException(
            'Failed to parse Gemini function response: $e\nResponse text: $text');
      }
    } on GenerativeAIException catch (e) {
      if (e.toString().contains('403') ||
          e.toString().toLowerCase().contains('api key')) {
        throw ApiKeyException('Invalid API Key provided', e);
      }
      throw AppBaseException('AI Service Error', e);
    } on SocketException catch (e) {
      throw NetworkException('No internet connection', e);
    } catch (e) {
      // Check if it's already one of our exceptions
      if (e is AppBaseException) rethrow;
      throw AppBaseException('Unexpected error communicating with AI', e);
    }
  }
}
