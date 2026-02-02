import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/services/ai_prompt_builder.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';

// Static instruction removed in favor of dynamic generation

class TurnResult {
  final String narrative;
  final Map<String, dynamic> stateUpdates;
  final FunctionCall? functionCall;
  final List<SkillOption> suggestedActions; // Task 1: Three Card options

  TurnResult({
    required this.narrative,
    required this.stateUpdates,
    this.functionCall,
    this.suggestedActions = const [],
  });

  // Factory constructor to parse the JSON string from Gemini
  factory TurnResult.fromJson(Map<String, dynamic> json,
      {FunctionCall? functionCall}) {
    // Parse suggested_actions if present
    List<SkillOption> options = [];
    if (json['suggested_actions'] != null &&
        json['suggested_actions'] is List) {
      options = (json['suggested_actions'] as List)
          .map((e) => SkillOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return TurnResult(
      narrative: json['narrative']?.toString() ?? '',
      stateUpdates: (json['state_updates'] is Map)
          ? Map<String, dynamic>.from(json['state_updates'])
          : {},
      functionCall: functionCall,
      suggestedActions: options,
    );
  }
}

/// Represents a skill check option for the "Three Card" system.
/// The AI suggests 3 approaches and the player picks one.
class SkillOption {
  final String label; // e.g., "Force Open"
  final String skill; // e.g., "Athletics"
  final String attribute; // e.g., "STR"
  final int difficulty;

  SkillOption({
    required this.label,
    required this.skill,
    required this.attribute,
    required this.difficulty,
  });

  factory SkillOption.fromJson(Map<String, dynamic> json) {
    return SkillOption(
      label: json['label']?.toString() ?? 'Unknown',
      skill: json['skill']?.toString() ?? 'General',
      attribute: json['attribute']?.toString() ?? 'INT',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 10,
    );
  }
}

class GeminiService {
  final String _apiKey;
  final String _modelName;
  ChatSessionWrapper? _currentSession;
  int? _currentWorldId;
  // Track player state to detect changes requiring session refresh
  int? _lastPlayerLevel;

  GeminiService(this._apiKey, {String modelName = 'gemini-1.5-flash'})
      : _modelName = modelName;

  /// Factory method to create the model (wrapped)
  GenerativeModelWrapper createModel(String instruction) {
    final realModel = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
          // responseMimeType: 'application/json', // Unsupported with Tools in some versions
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
    String? worldKnowledge,
  }) async {
    // Fetch inventory first (needed for both session init and context)
    final inventory = await dao.getInventoryForCharacter(player.id);

    // Check if session needs refresh (world changed OR player class/level changed)
    final needsRefresh = _currentSession == null ||
        _currentWorldId != worldId ||
        _lastPlayerLevel != player.level;

    if (needsRefresh) {
      // Log Removed
      final instruction = AIPromptBuilder.buildInstruction(
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
      _lastPlayerLevel = player.level;
    } else {
      // Log Removed
    }

    final prompt = AIPromptBuilder.buildContextPrompt(
      userMessage,
      player,
      inventory,
      worldKnowledge: worldKnowledge,
    );

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
      if (e.toString().contains('429') ||
          e.toString().toLowerCase().contains('quota')) {
        throw QuotaExceededException(
            "You've exceeded your 20 requests per minute. Please wait a moment.",
            e);
      }
      print('🚨 GEMINI AI EXCEPTION: $e');
      throw AppBaseException('AI Service Error: $e', e);
    } on SocketException catch (e) {
      print('🚨 NETWORK EXCEPTION: $e');
      throw NetworkException('No internet connection', e);
    } catch (e) {
      print('🚨 UNEXPECTED GEMINI ERROR: $e');
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

    // Parse JSON safely
    try {
      final text = response.text ?? '';

      // Attempt to extract JSON substring if narrative is mixed in
      String jsonStr = text;
      final int start = text.indexOf('{');
      final int end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        jsonStr = text.substring(start, end + 1);
      } else {
        // No JSON brackets found? Assuming it's pure narrative.
        // We'll treat the whole text as narrative and empty updates.
        return TurnResult(
            narrative: text, stateUpdates: {}, functionCall: null);
      }

      final cleanJson =
          jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;

      return TurnResult.fromJson(json);
    } catch (e) {
      // Fallback: If parsing fails, return text as narrative
      // This prevents crashes on "I try to cast..." text responses
      print('⚠️ JSON Parse Warning: $e. Returning raw text.');
      return TurnResult(
          narrative: response.text ?? '', stateUpdates: {}, functionCall: null);
    }
  }

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

  /// Tool definition for trade transactions
  static final Tool tradeTool = Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'trade_transaction',
        'Handle buying or selling items with an NPC merchant. Use this when the player wants to buy or sell items.',
        Schema.object(
          properties: {
            'action': Schema.enumString(
              enumValues: ['buy', 'sell'],
              description:
                  'Transaction type: "buy" (player buying) or "sell" (player selling)',
            ),
            'item_name':
                Schema.string(description: 'Name of the item to trade'),
            'quantity': Schema.integer(description: 'Quantity of the item'),
            'gold_amount': Schema.integer(
                description: 'Total gold cost/value (positive integer).'),
          },
          requiredProperties: [
            'action',
            'item_name',
            'quantity',
            'gold_amount'
          ],
        ),
      ),
    ],
  );

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
        final text = result.text ?? '';

        String jsonStr = text;
        final int start = text.indexOf('{');
        final int end = text.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = text.substring(start, end + 1);
        } else {
          return TurnResult(
              narrative: text, stateUpdates: {}, functionCall: null);
        }

        final cleanJson =
            jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
        final json = jsonDecode(cleanJson) as Map<String, dynamic>;

        return TurnResult.fromJson(json);
      } catch (e) {
        // Fallback for function response too
        print('⚠️ JSON Parse Warning (Function): $e. Returning raw text.');
        return TurnResult(
            narrative: result.text ?? '', stateUpdates: {}, functionCall: null);
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

  /// Generates content from a single prompt without session history.
  /// Useful for auxiliary tasks like summarization, analysis, or book generation.
  /// Optionally accepts model and API key overrides for ghostwriting.
  Future<String> generateContent(String prompt,
      {String? modelOverride, String? apiKeyOverride}) async {
    // Create a fresh model instance for this one-off task
    final model = GenerativeModel(
      model: modelOverride ?? _modelName,
      apiKey: apiKeyOverride ?? _apiKey,
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      print('🚨 GEMINI AUXILIARY GENERATION ERROR: $e');
      throw AppBaseException('Failed to generate auxiliary content', e);
    }
  }
}
