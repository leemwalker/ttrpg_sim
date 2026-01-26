import 'package:ttrpg_sim/features/game/services/game_action_handler.dart';

import 'package:ttrpg_sim/core/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';

part 'game_controller.g.dart';

@riverpod
class GameController extends _$GameController {
  late int _worldId;
  late int _characterId;

  @override
  Future<GameState> build(int worldId, int characterId) async {
    _worldId = worldId;
    _characterId = characterId;
    final dao = ref.read(gameDaoProvider);
    final messages = await dao.getRecentMessages(
        _characterId, AppConstants.chatHistoryLimit);
    // Check for Session Zero trigger
    if (messages.isEmpty) {
      // Trigger Session Zero asynchronously
      Future.microtask(() => _startSessionZero());

      // Return loading state initially
      return const GameState(
        messages: [],
        character: null,
        inventory: [],
        isLoading: true,
      );
    }

    return GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
    );
  }

  Future<void> submitAction(String text) async {
    if (text.trim().isEmpty) return;

    state = const AsyncValue.loading();

    final dao = ref.read(gameDaoProvider);
    final worldId = _worldId;

    try {
      final gemini = ref.read(geminiServiceProvider);

      // Save user message (scoped to this character)
      await dao.insertMessage('user', text, worldId, _characterId);

      // Fetch World Context
      final world = await dao.getWorld(worldId);
      final genre = world?.genre ?? "Fantasy";
      final tone = world?.tone ?? "Standard";
      final description = world?.description ?? "A standard fantasy world.";

      // Fetch Character
      final character = await dao.getCharacterById(_characterId);
      if (character == null) {
        throw Exception('No character found with id $_characterId');
      }

      // Fetch Rules Context
      final rules = Dnd5eRules();
      final features =
          rules.getClassFeatures(character.heroClass, character.level);
      final slots =
          rules.getMaxSpellSlots(character.heroClass, character.level);
      final spells = rules.getKnownSpells(character.heroClass, character.level);

      // Fetch Atlas Data (Location, POIs, NPCs) if character has a location
      Location? location;
      List<PointsOfInterestData> pois = [];
      List<Npc> npcs = [];

      if (character.currentLocationId != null) {
        location = await dao.getLocation(character.currentLocationId!);
        if (location != null) {
          pois = await dao.getPoisForLocation(location.id);
          npcs = await dao.getNpcsForLocation(location.id);
        }
      }

      // Fetch shared world data for context injection
      final knownLocations = await dao.getLocationsForWorld(worldId);
      final knownNpcs = await dao.getNpcsForWorld(worldId);

      // Build world knowledge section for prompt
      final worldKnowledge = (knownLocations.isNotEmpty || knownNpcs.isNotEmpty)
          ? '''
[PERSISTENT WORLD DATA]
The following locations and NPCs already exist in this world. Use these details to maintain consistency if the player encounters them:
Locations: ${knownLocations.map((l) => "${l.name}: ${l.description}").join('; ')}
NPCs: ${knownNpcs.map((n) => "${n.name}: ${n.role}").join('; ')}
'''
          : null;

      // Call Gemini (includes world knowledge if available)
      final result = await gemini.sendMessage(
        text,
        dao,
        worldId,
        genre: genre,
        tone: tone,
        description: description,
        player: character,
        features: features,
        spellSlots: slots,
        spells: spells,
        location: location,
        pois: pois,
        npcs: npcs,
        worldKnowledge:
            worldKnowledge, // Pass context explicitly if GeminiService supports it, or it will be built in the builder
      );

      // Handle Result (Function Calls, State Updates, Narrative)
      await _handleTurnResult(result, dao, gemini, rules, worldId);
    } catch (e) {
      _handleError(e, dao, worldId);
    }
  }

  Future<void> _startSessionZero() async {
    final dao = ref.read(gameDaoProvider);
    final rules = Dnd5eRules();

    try {
      final gemini = ref.read(geminiServiceProvider);
      final world = await dao.getWorld(_worldId);
      final character = await dao.getCharacterById(_characterId);

      if (world == null || character == null) {
        state = const AsyncValue.data(GameState(
          messages: [],
          character: null,
          inventory: [],
          isLoading: false,
        ));
        return;
      }

      final features =
          rules.getClassFeatures(character.heroClass, character.level);
      final slots =
          rules.getMaxSpellSlots(character.heroClass, character.level);
      final spells = rules.getKnownSpells(character.heroClass, character.level);

      final result = await gemini.sendMessage(
        "Begin Session Zero",
        dao,
        _worldId,
        genre: world.genre,
        tone: world.tone,
        description: world.description,
        player: character,
        features: features,
        spellSlots: slots,
        spells: spells,
        location: null,
      );

      await _handleTurnResult(result, dao, gemini, rules, _worldId);
    } catch (e) {
      _handleError(e, dao, _worldId);
    }
  }

  Future<void> _handleTurnResult(
    TurnResult result,
    GameDao dao,
    GeminiService gemini,
    Dnd5eRules rules,
    int worldId,
  ) async {
    var currentResult = result;
    String narrative = currentResult.narrative;

    // Handle Function Calls
    if (currentResult.functionCall != null) {
      final handler = GameActionHandler(dao, rules);
      final functionResult = await handler.handleFunctionCall(
        functionCall: currentResult.functionCall!,
        worldId: worldId,
        characterId: _characterId,
        gemini: gemini,
      );

      if (functionResult != null) {
        currentResult = functionResult;
        narrative = currentResult.narrative;
      }
    }

    // Apply State Updates
    if (currentResult.stateUpdates.isNotEmpty) {
      final handler = GameActionHandler(dao, rules);
      await handler.processStateUpdates(
          currentResult.stateUpdates, _characterId);
    }

    // Force Refresh UI
    await Future.delayed(
        const Duration(milliseconds: AppConstants.aiTypingDelayMs));
    ref.invalidate(characterDataProvider(worldId));
    final c = await dao.getCharacterById(_characterId);
    if (c != null) {
      ref.invalidate(inventoryDataProvider(c.id));
    }

    // Save AI/Narrative Message
    await dao.insertMessage('ai', narrative, worldId, _characterId);

    // Update State
    final messages = await dao.getRecentMessages(
        _characterId, AppConstants.chatHistoryLimit);
    state = AsyncValue.data(GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
    ));
  }

  Future<void> _handleError(Object e, GameDao dao, int worldId) async {
    String errorMsg;
    if (e is ApiKeyException) {
      errorMsg = "⛔ Auth Error: Please check your API Key in Settings.";
    } else if (e is NetworkException) {
      errorMsg = "📡 Network Error: Unable to reach the oracle.";
    } else if (e is AppBaseException) {
      errorMsg = "❌ Error: ${e.message}";
    } else {
      errorMsg = "❌ Error: $e";
    }

    await dao.insertMessage('system', errorMsg, worldId, _characterId);

    final messages = await dao.getRecentMessages(
        _characterId, AppConstants.chatHistoryLimit);
    state = AsyncValue.data(GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
    ));
  }
}
