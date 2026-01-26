import 'package:ttrpg_sim/core/utils/dice_utils.dart';
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
    final gemini = ref.read(geminiServiceProvider);
    final worldId = _worldId;

    try {
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
      String? worldKnowledge;
      if (knownLocations.isNotEmpty || knownNpcs.isNotEmpty) {
        worldKnowledge = '''
[PERSISTENT WORLD DATA]
The following locations and NPCs already exist in this world. Use these details to maintain consistency if the player encounters them:
Locations: ${knownLocations.map((l) => "${l.name}: ${l.description}").join('; ')}
NPCs: ${knownNpcs.map((n) => "${n.name}: ${n.role}").join('; ')}
''';
      }

      // Call Gemini (includes world knowledge if available)
      final result = await gemini.sendMessage(
        worldKnowledge != null ? '$text\n\n$worldKnowledge' : text,
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
      );

      // Handle Result (Function Calls, State Updates, Narrative)
      await _handleTurnResult(result, dao, gemini, rules, worldId);
    } catch (e) {
      _handleError(e, dao, worldId);
    }
  }

  Future<void> _startSessionZero() async {
    final dao = ref.read(gameDaoProvider);
    final gemini = ref.read(geminiServiceProvider);
    final rules = Dnd5eRules();

    try {
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
      final fc = currentResult.functionCall!;

      if (fc.name == 'generate_location') {
        final args = fc.args;
        final locName = args['name'] as String? ?? 'Unknown Location';
        final locDesc = args['description'] as String? ?? 'A mysterious place.';
        final locType = args['type'] as String? ?? 'Wilderness';
        final poisData = args['pois'] as List<dynamic>? ?? [];
        final npcsData = args['npcs'] as List<dynamic>? ?? [];

        final locationId = await dao.createLocationFromValues(
          worldId: worldId,
          name: locName,
          description: locDesc,
          type: locType,
        );

        for (final poi in poisData) {
          if (poi is Map<String, dynamic>) {
            await dao.createPoiFromValues(
              locationId: locationId,
              name: poi['name'] as String? ?? 'Unknown POI',
              description: poi['description'] as String? ?? '',
              type: poi['type'] as String? ?? 'Unknown',
            );
          }
        }

        for (final npc in npcsData) {
          if (npc is Map<String, dynamic>) {
            await dao.createNpcFromValues(
              worldId: worldId,
              locationId: locationId,
              name: npc['name'] as String? ?? 'Unknown NPC',
              role: npc['role'] as String? ?? 'Commoner',
              description: npc['description'] as String? ?? '',
            );
          }
        }

        final char = await dao.getCharacterById(_characterId);
        if (char != null) {
          await dao.updateCharacterLocation(char.id, locationId);
        }

        narrative = 'You arrive at **$locName**. $locDesc';
        ref.invalidate(characterDataProvider(worldId));
      }

      if (fc.name == 'roll_check') {
        final args = fc.args;
        final checkName = args['check_name'] as String? ?? 'dexterity';
        final difficulty = args['difficulty'] as int? ?? 10;

        final char = await dao.getCharacterById(_characterId);
        // Default to +0 if char is missing (should verify char existence before)
        final mod = char != null ? rules.getModifier(char, checkName) : 0;

        final roll = DiceUtils.rollD20();
        final total = roll + mod;
        final isSuccess = total >= difficulty;

        final systemMsg = "🎲 **\${args['check_name']} Check**\n"
            "Roll: $roll + $mod = **$total** vs DC $difficulty\n"
            "\${isSuccess ? '✅ SUCCESS' : '❌ FAILURE'}";

        await dao.insertMessage('system', systemMsg, worldId, _characterId);

        final rollResult = await gemini.sendFunctionResponse('roll_check', {
          'roll': roll,
          'modifier': mod,
          'total': total,
          'success': isSuccess,
          'check_name': checkName,
          'difficulty': difficulty,
        });

        currentResult = rollResult;
        narrative = currentResult.narrative;
      }
    }

    // Apply State Updates
    if (currentResult.stateUpdates.isNotEmpty) {
      final updates = currentResult.stateUpdates;
      final currentCharacter = await dao.getCharacterById(_characterId);

      if (currentCharacter != null) {
        if (updates.containsKey('hp_change')) {
          final change = updates['hp_change'];
          if (change != null && change is int) {
            final newHp = (currentCharacter.currentHp + change)
                .clamp(0, currentCharacter.maxHp);
            await dao.forceUpdateHp(currentCharacter.id, newHp);
            ref.invalidate(characterDataProvider(worldId));
          }
        }

        if (updates.containsKey('gold_change')) {
          final change = updates['gold_change'] as int? ?? 0;
          final newGold = currentCharacter.gold + change;
          await dao.updateGold(currentCharacter.id, newGold);
        }

        if (updates.containsKey('location_update')) {
          final newLoc = updates['location_update'] as String?;
          if (newLoc != null) {
            await dao.updateLocation(currentCharacter.id, newLoc);
          }
        }

        if (updates.containsKey('add_items')) {
          final items = updates['add_items'] as List<dynamic>?;
          if (items != null) {
            for (final item in items) {
              await dao.addItem(currentCharacter.id, item as String);
            }
          }
        }

        if (updates.containsKey('remove_items')) {
          final items = updates['remove_items'] as List<dynamic>?;
          if (items != null) {
            for (final item in items) {
              await dao.removeItem(currentCharacter.id, item as String);
            }
          }
        }
      }
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
