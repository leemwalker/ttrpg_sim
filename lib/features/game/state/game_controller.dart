import 'package:ttrpg_sim/core/utils/dice_utils.dart';
import 'package:ttrpg_sim/core/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';

part 'game_controller.g.dart';

@riverpod
class GameController extends _$GameController {
  late int _worldId;

  @override
  Future<GameState> build(int worldId) async {
    _worldId = worldId;
    final dao = ref.read(gameDaoProvider);
    final messages =
        await dao.getRecentMessages(_worldId, AppConstants.chatHistoryLimit);
    // Check for Session Zero trigger
    if (messages.isEmpty) {
      // Trigger Session Zero asynchronously
      Future.microtask(() => _startSessionZero());

      // Return loading state initially
      return GameState(
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
    // final db = ref.read(databaseProvider);
    final worldId = _worldId;

    try {
      // Log Removed

      // Save user message (Global chat for now as per schema)
      await dao.insertMessage('user', text, worldId);

      // Fetch World Context
      final world = await dao.getWorld(worldId);
      final genre = world?.genre ?? "Fantasy";
      final tone = world?.tone ?? "Standard";
      final description = world?.description ?? "A standard fantasy world.";

      // Fetch Character
      final character = await dao.getCharacter(worldId);
      if (character == null) {
        throw Exception('No character found for world $worldId');
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

      // Call Gemini
      var result = await gemini.sendMessage(
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
      );

      // Handle Function Calls (Tool Use)
      String narrative = result.narrative;
      if (result.functionCall != null) {
        final fc = result.functionCall!;
        if (fc.name == 'generate_location') {
          // print('✨ GENERATING LOCATION from function call...');
          final args = fc.args;

          // Parse arguments
          final locName = args['name'] as String? ?? 'Unknown Location';
          final locDesc =
              args['description'] as String? ?? 'A mysterious place.';
          final locType = args['type'] as String? ?? 'Wilderness';
          final poisData = args['pois'] as List<dynamic>? ?? [];
          final npcsData = args['npcs'] as List<dynamic>? ?? [];

          // Create the location
          final locationId = await dao.createLocationFromValues(
            worldId: worldId,
            name: locName,
            description: locDesc,
            type: locType,
          );
          // print('✨ GENERATED LOCATION: $locName (ID: $locationId)');

          // Create POIs
          for (final poi in poisData) {
            if (poi is Map<String, dynamic>) {
              await dao.createPoiFromValues(
                locationId: locationId,
                name: poi['name'] as String? ?? 'Unknown POI',
                description: poi['description'] as String? ?? '',
                type: poi['type'] as String? ?? 'Unknown',
              );
              // print('  📍 Created POI: ${poi['name']}');
            }
          }

          // Create NPCs
          for (final npc in npcsData) {
            if (npc is Map<String, dynamic>) {
              await dao.createNpcFromValues(
                worldId: worldId,
                locationId: locationId,
                name: npc['name'] as String? ?? 'Unknown NPC',
                role: npc['role'] as String? ?? 'Commoner',
                description: npc['description'] as String? ?? '',
              );
              // print('  👤 Created NPC: ${npc['name']}');
            }
          }

          // Update character's location
          await dao.updateCharacterLocation(character.id, locationId);
          // print('📍 Updated character location to: $locName');

          // Generate a welcome narrative since the function call had no text
          narrative = 'You arrive at **$locName**. $locDesc';

          // Invalidate to refresh UI with new location
          ref.invalidate(characterDataProvider(worldId));
        }

        if (fc.name == 'roll_check') {
          // print('🎲 DICE ROLL requested...');
          final args = fc.args;
          final checkName = args['check_name'] as String? ?? 'dexterity';
          final difficulty = args['difficulty'] as int? ?? 10;

          // Calculate modifier
          final mod = rules.getModifier(character, checkName);

          // Roll d20
          final roll = DiceUtils.rollD20();
          final total = roll + mod;
          final isSuccess = total >= difficulty;

          /*
          print(
              '🎲 $checkName check: rolled $roll + $mod = $total vs DC $difficulty -> ${isSuccess ? "SUCCESS" : "FAILURE"}');
          */

          // Log System Message
          final systemMsg = "🎲 **${args['check_name']} Check**\n"
              "Roll: $roll + $mod = **$total** vs DC $difficulty\n"
              "${isSuccess ? '✅ SUCCESS' : '❌ FAILURE'}";
          await dao.insertMessage('system', systemMsg, worldId);

          // Send result back to Gemini for narrative
          final rollResult = await gemini.sendFunctionResponse('roll_check', {
            'roll': roll,
            'modifier': mod,
            'total': total,
            'success': isSuccess,
            'check_name': checkName,
            'difficulty': difficulty,
          });

          // Update result so narrative and state updates are applied
          result = rollResult;
          narrative = result.narrative;
        }
      }

      // print('🎮 CONTROLLER: Received updates: ${result.stateUpdates}');

      // Apply Updates (Additive Math)
      if (result.stateUpdates.isNotEmpty) {
        final currentCharacter = await dao.getCharacter(worldId);
        if (currentCharacter != null) {
          final updates = result.stateUpdates;

          if (updates.containsKey('hp_change')) {
            final change = updates['hp_change'];
            if (change != null && change is int) {
              // 1. Fetch the LATEST fresh copy of the character
              final freshChar = await dao.getCharacter(worldId);
              if (freshChar != null) {
                // 2. Calculate new HP
                final currentHp = freshChar.currentHp;
                // Ensure we don't go below 0 or above Max
                final newHp = (currentHp + change).clamp(0, freshChar.maxHp);
                final charId = freshChar.id;

                // print('⚡ RAW SQL: Forcing update for ID $charId to HP $newHp');

                // 3. Execute Raw SQL
                await dao.forceUpdateHp(charId, newHp);

                // 4. Verify immediately
                final verification = await dao.getCharacter(worldId);
                if (verification?.currentHp == newHp) {
                  // print('✅ VERIFIED: DB now holds HP ${verification?.currentHp}');
                } else {
                  // print('❌ CRITICAL FAILURE: DB still holds HP ${verification?.currentHp}');
                }

                // 5. Refresh UI
                ref.invalidate(characterDataProvider(worldId));
              }
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

          // Refresh context
          if (result.stateUpdates.containsKey('add_items')) {
            final items = result.stateUpdates['add_items'] as List<dynamic>?;
            if (items != null) {
              for (final item in items) {
                await dao.addItem(currentCharacter.id, item as String);
              }
            }
          }

          if (result.stateUpdates.containsKey('remove_items')) {
            final items = result.stateUpdates['remove_items'] as List<dynamic>?;
            if (items != null) {
              for (final item in items) {
                await dao.removeItem(currentCharacter.id, item as String);
              }
            }
          }
        }
      }

      // FORCE REFRESH: Tell the UI stream to re-fetch data immediately
      await Future.delayed(const Duration(
          milliseconds: AppConstants.aiTypingDelayMs)); // The "Breath"
      ref.invalidate(characterDataProvider(worldId));

      final c = await dao.getCharacter(worldId);
      if (c != null) {
        ref.invalidate(inventoryDataProvider(c.id));
      }

      // print('🔄 CONTROLLER: Invalidated Streams to force UI update.');

      // Save AI message
      await dao.insertMessage('ai', narrative, worldId);

      // Reload messages
      final messages =
          await dao.getRecentMessages(worldId, AppConstants.chatHistoryLimit);
      state = AsyncValue.data(GameState(
        messages: messages,
        character: null,
        inventory: [],
        isLoading: false,
      ));
    } catch (e) {
      // print('❌ ERROR: $e');

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

      // Persist error system message
      await dao.insertMessage('system', errorMsg, worldId);

      // Reload messages to show the error
      final messages =
          await dao.getRecentMessages(worldId, AppConstants.chatHistoryLimit);

      // Update state to valid data (not error) so UI updates
      state = AsyncValue.data(GameState(
        messages: messages,
        character: null,
        inventory: [],
        isLoading: false,
      ));
    }
  }

  Future<void> _startSessionZero() async {
    final dao = ref.read(gameDaoProvider);
    final gemini = ref.read(geminiServiceProvider);
    final rules = Dnd5eRules();

    try {
      final world = await dao.getWorld(_worldId);
      final character = await dao.getCharacter(_worldId);

      if (world == null || character == null) {
        state = AsyncValue.data(GameState(
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

      await dao.insertMessage('ai', result.narrative, _worldId);

      final messages =
          await dao.getRecentMessages(_worldId, AppConstants.chatHistoryLimit);
      state = AsyncValue.data(GameState(
        messages: messages,
        character: character,
        inventory: [],
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncValue.data(GameState(
        messages: [],
        character: null,
        inventory: [],
        isLoading: false,
      ));
      await dao.insertMessage(
          'system', 'Error starting Session Zero: $e', _worldId);
    }
  }
}
