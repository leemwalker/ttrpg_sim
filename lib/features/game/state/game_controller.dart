import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ttrpg_sim/features/game/services/game_action_handler.dart';

import 'package:ttrpg_sim/core/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/core_rpg_rules.dart';
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

    // Initial word count fetch
    final wordCount = await dao.getWordCount(_characterId);

    return GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
      wordCount: wordCount,
      bookCompletion: (wordCount / 50000).clamp(0.0, 1.0),
    );
  }

  // Allows UI to await the story analysis result
  Future<String> runStoryAnalysis() async {
    final generator = ref.read(storyGeneratorServiceProvider);
    try {
      return await generator.analyzeArc(_characterId);
    } catch (e) {
      return "Error analyzing story: $e";
    }
  }

  Future<void> exportBook() async {
    final generator = ref.read(storyGeneratorServiceProvider);
    final pdfService = ref.read(pdfExportServiceProvider);
    final dao = ref.read(gameDaoProvider);

    // update state to Generating
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(
          isGeneratingBook: true, generationStatus: "Initializing..."));
    }

    try {
      // Listen to stream
      String fullBookText = "";
      await for (final status in generator.streamBookGeneration(_characterId)) {
        if (status.startsWith("COMPLETE:")) {
          fullBookText = status.substring("COMPLETE:".length);
        } else {
          // Update status
          state =
              AsyncValue.data(state.value!.copyWith(generationStatus: status));
        }
      }

      state = AsyncValue.data(
          state.value!.copyWith(generationStatus: "Generating PDF..."));

      final char = await dao.getCharacterById(_characterId);
      if (char != null) {
        final file = await pdfService.generatePdf(fullBookText, char);
        // Log the file path for debugging purposes
        debugPrint("PDF saved to: ${file.path}");
        // TODO: In a real app, share the file via share_plus or open it.
      }
    } catch (e) {
      debugPrint("Error exporting book: $e");
    } finally {
      state = AsyncValue.data(
          state.value!.copyWith(isGeneratingBook: false, generationStatus: ""));
    }
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
      final rules =
          CoreRpgRules(); // Legacy logic kept for dice/checks, but features loaded from JSON

      // Parse Features
      final List<String> features = [];
      try {
        final traits = (jsonDecode(character.traits) as List)
            .map((e) => e.toString())
            .toList();
        final feats = (jsonDecode(character.feats) as List)
            .map((e) => e.toString())
            .toList();
        features.addAll(traits);
        features.addAll(feats);
      } catch (e) {
        // ignore error
      }

      // Magic columns not yet fully implemented, passing empty for now or checking skills
      final slots = <String, int>{};
      final spells = <String>[];

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
    final rules = CoreRpgRules();

    try {
      final gemini = ref.read(geminiServiceProvider);
      final world = await dao.getWorld(_worldId);
      final character = await dao.getCharacterById(_characterId);

      if (world == null || character == null) {
        state = AsyncValue.data(GameState(
          messages: [
            ChatMessage(
                id: 0,
                role: MessageRole.system,
                content:
                    "Error: World or Character not found (W:$_worldId, C:$_characterId).",
                timestamp:
                    DateTime.now(), // Fixed: Use DateTime.now() vs arbitrary
                worldId: _worldId,
                characterId: _characterId)
          ],
          character: null,
          inventory: [],
          isLoading: false,
        ));
        return;
      }

      final List<String> features = [];
      try {
        final traits = (jsonDecode(character.traits) as List)
            .map((e) => e.toString())
            .toList();
        final feats = (jsonDecode(character.feats) as List)
            .map((e) => e.toString())
            .toList();
        features.addAll(traits);
        features.addAll(feats);
      } catch (e) {
        // ignore
      }
      final slots = <String, int>{};
      final spells = <String>[];

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
    CoreRpgRules rules,
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

    // Update word count
    final wordCount = await dao.getWordCount(_characterId);

    state = AsyncValue.data(GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
      wordCount: wordCount,
      bookCompletion: (wordCount / 50000).clamp(0.0, 1.0),
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
