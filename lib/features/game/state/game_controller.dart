import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ttrpg_sim/features/game/services/context_service.dart';
import 'package:ttrpg_sim/features/game/services/game_action_handler.dart';
import 'package:ttrpg_sim/features/character/services/progression_service.dart';

import 'package:ttrpg_sim/core/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/core_rpg_rules.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';
import 'package:ttrpg_sim/core/utils/dice_utils.dart';

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

    final dao = ref.read(gameDaoProvider);
    final worldId = _worldId;

    // --- TASK 4: OPTIMISTIC UPDATE ---
    // 1. Create optimistic user message (temporary ID = -1)
    final optimisticUserMessage = ChatMessage(
      id: -1, // Temp ID, will be replaced
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
      worldId: worldId,
      characterId: _characterId,
    );

    // 2. Get current messages and add optimistic one + set typing indicator
    final currentMessages = state.value?.messages ?? [];
    state = AsyncValue.data((state.value ?? const GameState()).copyWith(
      messages: [optimisticUserMessage, ...currentMessages],
      isTyping: true,
      lastError: null, // Clear previous errors
      pendingSkillCheck: [], // Clear any pending skill checks
    ));

    try {
      final gemini = ref.read(geminiServiceProvider);

      // Save user message (scoped to this character)
      await dao.insertMessage('user', text, worldId, _characterId);

      // Fetch World Context
      final world = await dao.getWorld(worldId);
      final genre = world?.genre ?? "Fantasy";
      final tone = world?.tone ?? "Standard";

      final description = world?.description ?? "A standard fantasy world.";

      // Parse Species Config
      String speciesContext = "";
      if (world != null && world.speciesConfig != '{}') {
        try {
          final config =
              jsonDecode(world.speciesConfig) as Map<String, dynamic>;
          final excluded = List<String>.from(config['excluded'] ?? []);
          final included = List<String>.from(config['included'] ?? []);
          final custom =
              (config['custom'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // We don't have the full list of "Core" species here easily without the rules controller,
          // but valid species are implicitly: (Standard for Genre - Excluded) + Included + Custom.
          // Since we can't easily list "Standard for Genre" without loading rules, we might just list the Explicit ones?
          // Or we can load rules.
          await ModularRulesController().loadRules();
          final allSpecies = ModularRulesController().getSpecies([genre]);

          final validNames = allSpecies
              .map((s) => s.name)
              .where((name) => !excluded.contains(name))
              .toList();

          validNames.addAll(included);

          final customDescriptions = custom
              .map((c) => "${c['name']} (${c['stats']}, ${c['traits']})")
              .toList();

          speciesContext =
              "\n[VALID SPECIES]\nNative: ${validNames.join(', ')}\nCustom/Exotic: ${customDescriptions.join(', ')}";
        } catch (e) {
          debugPrint("Error parsing species config: $e");
        }
      }

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

      // Fetch filtered world data for context injection (only relevant items)
      final contextService = ContextService(dao);
      final recentMessages = await dao.getRecentMessages(_characterId, 6);
      final worldKnowledge = await contextService.buildRelevantWorldData(
        worldId,
        character.currentLocationId,
        recentMessages,
        speciesContext: speciesContext,
      );

      // Fetch Imagin8 Context if applicable
      List<Imagin8Card> handCards = [];
      List<Imagin8Card> discardCards = [];
      final system = world?.system ?? 'd20';

      if (system == 'imagin8') {
        try {
          final hIds = (jsonDecode(character.hand ?? '[]') as List)
              .map((e) => int.parse(e.toString()))
              .toList();
          final dIds = (jsonDecode(character.discardPile ?? '[]') as List)
              .map((e) => int.parse(e.toString()))
              .toList();

          if (hIds.isNotEmpty) {
            handCards = await dao.getImagin8CardsByIds(hIds);
          }
          if (dIds.isNotEmpty) {
            discardCards = await dao.getImagin8CardsByIds(dIds);
          }
        } catch (e) {
          debugPrint("Error fetching Imagin8 context: $e");
        }
      }

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
        system: system,
        hand: handCards,
        discard: discardCards,
      );

      // --- TASK 1: SKILL CHECK OPTIONS ---
      // Check if AI returned skill check options (strict fallback)
      if (result.suggestedActions.isNotEmpty) {
        // Enter skill check pending state - show cards, wait for selection
        final messages = await dao.getRecentMessages(
            _characterId, AppConstants.chatHistoryLimit);
        final wordCount = await dao.getWordCount(_characterId);

        state = AsyncValue.data(GameState(
          messages: messages,
          character: null,
          inventory: [],
          isLoading: false,
          isTyping: false,
          pendingSkillCheck: result.suggestedActions, // Store options for UI
          wordCount: wordCount,
          bookCompletion: (wordCount / 50000).clamp(0.0, 1.0),
        ));
        return; // Wait for user to select an option
      }

      // Handle Result (Function Calls, State Updates, Narrative)
      await _handleTurnResult(result, dao, gemini, rules, worldId);
    } catch (e) {
      // --- TASK 4: ERROR ROLLBACK ---
      // Remove optimistic message and show error
      await _handleErrorWithRollback(e, dao, worldId);
    }
  }

  /// Task 1: Handle skill check card selection
  /// Task 1: Handle skill check card selection
  Future<void> selectSkillOption(SkillOption option) async {
    final dao = ref.read(gameDaoProvider);
    final character = await dao.getCharacterById(_characterId);

    String rollResult = "";
    if (character != null) {
      final int attrScore = _getAttributeValue(character, option.attribute);
      final int mod = _getMod(attrScore);
      final roll = DiceUtils.roll("1d20+$mod");

      final bool isSuccess = roll.total >= option.difficulty;
      final String status = isSuccess ? "Success" : "Failure";

      rollResult =
          "Rolled ${roll.total} ($status) vs DC ${option.difficulty}. [1d20${mod >= 0 ? '+' : ''}$mod = ${roll.total}]";
    }

    // Auto-send message based on selected skill option with RESULT
    final message = "I choose: ${option.label}. $rollResult";

    // Clear pending skill check first
    state = AsyncValue.data((state.value ?? const GameState()).copyWith(
      pendingSkillCheck: [],
    ));

    // Submit as a regular action
    await submitAction(message);
  }

  int _getAttributeValue(CharacterData c, String attr) {
    switch (attr.trim().toUpperCase()) {
      case 'STR':
      case 'STRENGTH':
        return c.strength;
      case 'DEX':
      case 'DEXTERITY':
        return c.dexterity;
      case 'CON':
      case 'CONSTITUTION':
        return c.constitution;
      case 'INT':
      case 'INTELLIGENCE':
        return c.intelligence;
      case 'WIS':
      case 'WISDOM':
        return c.wisdom;
      case 'CHA':
      case 'CHARISMA':
        return c.charisma;
      default:
        return 10;
    }
  }

  int _getMod(int score) {
    return (score - 10) ~/ 2;
  }

  /// Task 1: Dismiss skill check and return to text input
  void dismissSkillCheck() {
    state = AsyncValue.data((state.value ?? const GameState()).copyWith(
      pendingSkillCheck: [],
    ));
  }

  /// Task 4: Error handling with optimistic rollback
  Future<void> _handleErrorWithRollback(
      Object e, GameDao dao, int worldId) async {
    String errorMsg;
    if (e is ApiKeyException) {
      errorMsg = "⛔ Auth Error: Please check your API Key in Settings.";
    } else if (e is NetworkException) {
      errorMsg = "📡 Network Error: Unable to reach the oracle.";
    } else if (e is AppBaseException) {
      errorMsg = "❌ Error: ${e.message}";
    } else {
      errorMsg = "❌ Message failed to send: $e";
    }

    // Fetch real messages from DB (without the failed optimistic one)
    final messages = await dao.getRecentMessages(
        _characterId, AppConstants.chatHistoryLimit);

    // Update state with error for SnackBar display
    state = AsyncValue.data(GameState(
      messages: messages,
      character: null,
      inventory: [],
      isLoading: false,
      isTyping: false,
      lastError: errorMsg, // For SnackBar display in UI
    ));
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
        system: world.system,
        hand: [], // Session zero has no cards usually, or we could fetch them if we wanted
        discard: [],
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
      final progression = ProgressionService(dao);
      final handler = GameActionHandler(dao, rules, progression);
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
      final progression = ProgressionService(dao);
      final handler = GameActionHandler(dao, rules, progression);
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

  Future<void> equipItem(String itemName) async {
    state = const AsyncValue.loading();
    final dao = ref.read(gameDaoProvider);
    final rules = ModularRulesController();

    try {
      final char = await dao.getCharacterById(_characterId);
      if (char == null) return;

      // 1. Validate Item
      final itemDef = rules.getItem(itemName);
      if (itemDef == null) {
        throw Exception("Unknown item: $itemName");
      }
      if (itemDef.slot == null) {
        throw Exception("Item cannot be equipped");
      }

      // 2. Check Ownership
      final inventory = await dao.getInventoryForCharacter(_characterId);
      final hasItem =
          inventory.any((i) => i.itemName == itemName && i.quantity > 0);
      if (!hasItem) {
        throw Exception("Item not in inventory");
      }

      // 3. Prepare Logic

      final equipment = jsonDecode(char.equipment) as Map<String, dynamic>;
      final slotKey = itemDef.slot!.name; // e.g. "mainHand"

      // 4. Handle Swap/Unequip
      if (equipment.containsKey(slotKey)) {
        final oldItemName = equipment[slotKey];
        await dao.addItem(
            _characterId, oldItemName); // Return valid item to inv
      }

      // 5. Equip
      equipment[slotKey] = itemName;
      await dao.removeItem(_characterId, itemName);

      // 6. Recalculate AC (if armor/dex affected)
      // Check equipped armor for DEX modifier clamping
      int dexMod = _getDexMod(char.dexterity);
      for (var equippedName in equipment.values) {
        final def = rules.getItem(equippedName);
        if (def != null && def.type == ItemType.armor) {
          final tags = def.tags;
          if (tags.contains('Heavy')) {
            dexMod = 0; // Heavy armor ignores DEX
            break;
          } else if (tags.contains('Medium')) {
            dexMod = dexMod.clamp(-5, 2); // Medium armor caps DEX at +2
            break;
          }
          // Light armor keeps full DEX modifier
        }
      }

      int ac = 10 + dexMod; // Base + (clamped) Dex
      // Iterate all equipped items for bonuses
      for (var equippedName in equipment.values) {
        final def = rules.getItem(equippedName);
        if (def != null && def.armorClassBonus != null) {
          ac += def.armorClassBonus!;
        }
      }

      // 7. Save
      await dao.updateCharacterStats(char.toCompanion(true).copyWith(
            equipment: drift.Value(jsonEncode(equipment)),
            armorClass: drift.Value(ac),
          ));

      // Refresh State
      ref.invalidate(characterDataProvider(_worldId));
      ref.invalidate(inventoryDataProvider(char.id));

      // Update UI state
      final messages = await dao.getRecentMessages(
          _characterId, AppConstants.chatHistoryLimit);
      final wordCount = await dao.getWordCount(_characterId);
      state = AsyncValue.data(GameState(
        messages: messages,
        character: null,
        inventory: [],
        isLoading: false,
        wordCount: wordCount,
        bookCompletion: (wordCount / 50000).clamp(0.0, 1.0),
      ));
    } catch (e) {
      _handleError(e, dao, _worldId);
    }
  }

  // --- IMAGIN8 CARD MECHANICS ---

  Future<void> playImagin8Card(int cardId) async {
    final dao = ref.read(gameDaoProvider);
    final char = await dao.getCharacterById(_characterId);
    if (char == null) return;

    try {
      final hand = List<int>.from(jsonDecode(char.hand ?? '[]'));
      final discard = List<int>.from(jsonDecode(char.discardPile ?? '[]'));

      if (hand.contains(cardId)) {
        hand.remove(cardId);
        discard.add(cardId);

        // Fetch card info for log
        final card = await dao.getImagin8Card(cardId);
        final cardName = card?.name ?? 'Unknown Card';

        await dao.updateCharacterStats(char.toCompanion(true).copyWith(
              hand: drift.Value(jsonEncode(hand)),
              discardPile: drift.Value(jsonEncode(discard)),
            ));

        await dao.insertMessage(
            'system', "🃏 **Played Card**: $cardName", _worldId, _characterId);

        // Update local state
        ref.invalidate(characterDataProvider(_worldId));
      }
    } catch (e) {
      debugPrint("Error playing card: $e");
    }
  }

  Future<void> recoverImagin8Card(int cardId) async {
    final dao = ref.read(gameDaoProvider);
    final char = await dao.getCharacterById(_characterId);
    if (char == null) return;

    try {
      final hand = List<int>.from(jsonDecode(char.hand ?? '[]'));
      final discard = List<int>.from(jsonDecode(char.discardPile ?? '[]'));

      if (discard.contains(cardId)) {
        discard.remove(cardId);
        hand.add(cardId);

        // Fetch card info for log
        final card = await dao.getImagin8Card(cardId);
        final cardName = card?.name ?? 'Unknown Card';

        await dao.updateCharacterStats(char.toCompanion(true).copyWith(
              hand: drift.Value(jsonEncode(hand)),
              discardPile: drift.Value(jsonEncode(discard)),
            ));

        await dao.insertMessage('system', "🔄 **Recovered Card**: $cardName",
            _worldId, _characterId);

        // Update local state
        ref.invalidate(characterDataProvider(_worldId));
      }
    } catch (e) {
      debugPrint("Error recovering card: $e");
    }
  }

  Future<void> recoverAllImagin8Cards() async {
    final dao = ref.read(gameDaoProvider);
    final char = await dao.getCharacterById(_characterId);
    if (char == null) return;

    try {
      final hand = List<int>.from(jsonDecode(char.hand ?? '[]'));
      final discard = List<int>.from(jsonDecode(char.discardPile ?? '[]'));

      if (discard.isNotEmpty) {
        hand.addAll(discard);
        discard.clear();

        await dao.updateCharacterStats(char.toCompanion(true).copyWith(
              hand: drift.Value(jsonEncode(hand)),
              discardPile: drift.Value(jsonEncode(discard)),
            ));

        await dao.insertMessage(
            'system', "🔄 **Recovered All Cards**", _worldId, _characterId);

        ref.invalidate(characterDataProvider(_worldId));
      }
    } catch (e) {
      debugPrint("Error recovering cards: $e");
    }
  }

  Future<void> rollImagin8Die([int faces = 8]) async {
    final dao = ref.read(gameDaoProvider);
    final roll = DiceUtils.roll("1d$faces");
    String result = "Rolled ${roll.total}";
    if (roll.total >= 8)
      result += " (Critical/Recover!)";
    else if (roll.total >= 5)
      result += " (Success)";
    else
      result += " (Failure/Complication)";

    await dao.insertMessage(
        'system', "🎲 **Risk Roll (d8)**: $result", _worldId, _characterId);

    // Refresh messages
    final messages = await dao.getRecentMessages(
        _characterId, AppConstants.chatHistoryLimit);
    state = AsyncValue.data(
        (state.value ?? const GameState()).copyWith(messages: messages));
  }

  Future<void> unequipItem(String slotName) async {
    state = const AsyncValue.loading();
    final dao = ref.read(gameDaoProvider);
    final rules = ModularRulesController();

    try {
      final char = await dao.getCharacterById(_characterId);
      if (char == null) return;

      final equipment = jsonDecode(char.equipment) as Map<String, dynamic>;
      if (!equipment.containsKey(slotName)) return;

      final itemName = equipment[slotName];

      // Remove from slot
      equipment.remove(slotName);
      // Add to inventory
      await dao.addItem(_characterId, itemName);

      // Recalculate AC with armor weight DEX clamping
      int dexMod = _getDexMod(char.dexterity);
      for (var equippedName in equipment.values) {
        final def = rules.getItem(equippedName);
        if (def != null && def.type == ItemType.armor) {
          final tags = def.tags;
          if (tags.contains('Heavy')) {
            dexMod = 0;
            break;
          } else if (tags.contains('Medium')) {
            dexMod = dexMod.clamp(-5, 2);
            break;
          }
        }
      }

      int ac = 10 + dexMod;
      for (var equippedName in equipment.values) {
        final def = rules.getItem(equippedName);
        if (def != null && def.armorClassBonus != null) {
          ac += def.armorClassBonus!;
        }
      }

      await dao.updateCharacter(char.copyWith(
        equipment: jsonEncode(equipment),
        armorClass: ac,
      ));

      ref.invalidate(characterDataProvider(_worldId));
      ref.invalidate(inventoryDataProvider(char.id));

      final messages = await dao.getRecentMessages(
          _characterId, AppConstants.chatHistoryLimit);
      final wordCount = await dao.getWordCount(_characterId);
      state = AsyncValue.data(GameState(
        messages: messages,
        character: null,
        inventory: [],
        isLoading: false,
        wordCount: wordCount,
        bookCompletion: (wordCount / 50000).clamp(0.0, 1.0),
      ));
    } catch (e) {
      _handleError(e, dao, _worldId);
    }
  }

  int _getDexMod(int score) {
    return (score - 10) ~/ 2;
  }
}
