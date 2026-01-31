import 'dart:convert';
import 'dart:math';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/utils/dice_utils.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/rules/core_rpg_rules.dart';

class GameActionHandler {
  final GameDao _dao;
  final CoreRpgRules _rules;

  GameActionHandler(this._dao, this._rules);

  Future<TurnResult?> handleFunctionCall({
    required FunctionCall functionCall,
    required int worldId,
    required int characterId,
    required GeminiService gemini,
  }) async {
    final fc = functionCall;

    if (fc.name == 'generate_location') {
      return await _handleGenerateLocation(fc, worldId, characterId);
    } else if (fc.name == 'roll_check') {
      return await _handleRollCheck(fc, worldId, characterId, gemini);
    }

    return null;
  }

  Future<TurnResult> _handleGenerateLocation(
      FunctionCall fc, int worldId, int characterId) async {
    final args = fc.args;
    final locName = args['name'] as String? ?? 'Unknown Location';
    final locDesc = args['description'] as String? ?? 'A mysterious place.';
    final locType = args['type'] as String? ?? 'Wilderness';
    final poisData = args['pois'] as List<dynamic>? ?? [];
    final npcsData = args['npcs'] as List<dynamic>? ?? [];

    final locationId = await _dao.createLocationFromValues(
      worldId: worldId,
      name: locName,
      description: locDesc,
      type: locType,
    );

    for (final poi in poisData) {
      if (poi is Map<String, dynamic>) {
        await _dao.createPoiFromValues(
          locationId: locationId,
          name: poi['name'] as String? ?? 'Unknown POI',
          description: poi['description'] as String? ?? '',
          type: poi['type'] as String? ?? 'Unknown',
        );
      }
    }

    for (final npc in npcsData) {
      if (npc is Map<String, dynamic>) {
        await _dao.createNpcFromValues(
          worldId: worldId,
          locationId: locationId,
          name: npc['name'] as String? ?? 'Unknown NPC',
          role: npc['role'] as String? ?? 'Commoner',
          description: npc['description'] as String? ?? '',
        );
      }
    }

    final char = await _dao.getCharacterById(characterId);
    if (char != null) {
      await _dao.updateCharacterLocation(char.id, locationId);
    }

    return TurnResult(
      narrative: 'You arrive at **$locName**. $locDesc',
      stateUpdates: {},
    );
  }

  Future<TurnResult> _handleRollCheck(FunctionCall fc, int worldId,
      int characterId, GeminiService gemini) async {
    final args = fc.args;
    final checkName = args['check_name'] as String? ?? 'dexterity';
    final difficulty = args['difficulty'] as int? ?? 10;

    final char = await _dao.getCharacterById(characterId);
    final mod = char != null ? _rules.getModifier(char, checkName) : 0;

    // Check for "Large" trait => Advantage on Strength and Athletics
    bool advantage = false;
    if (char != null) {
      try {
        final traitsList = jsonDecode(char.traits);
        if (traitsList is List && traitsList.contains('Large')) {
          final cName = checkName.toLowerCase();
          if (cName == 'strength' || cName == 'athletics') {
            advantage = true;
          }
        }
      } catch (e) {
        // Ignore parse error
      }
    }

    int roll = DiceUtils.rollD20();
    int roll2 = 0;
    if (advantage) {
      roll2 = DiceUtils.rollD20();
      roll = max(roll, roll2);
    }

    final total = roll + mod;
    final isSuccess = total >= difficulty;

    String systemMsg = "🎲 **${args['check_name']} Check**\n";
    if (advantage) {
      systemMsg += "(Advantage: rolled $roll and $roll2)\n";
    }
    systemMsg += "Roll: $roll + $mod = **$total** vs DC $difficulty\n"
        "${isSuccess ? '✅ SUCCESS' : '❌ FAILURE'}";

    await _dao.insertMessage('system', systemMsg, worldId, characterId);

    return await gemini.sendFunctionResponse('roll_check', {
      'roll': roll,
      'modifier': mod,
      'total': total,
      'success': isSuccess,
      'check_name': checkName,
      'difficulty': difficulty,
      'advantage': advantage, // Inform AI
    });
  }

  Future<void> processStateUpdates(
      Map<String, dynamic> updates, int characterId) async {
    final currentCharacter = await _dao.getCharacterById(characterId);
    if (currentCharacter == null) return;

    if (updates.containsKey('hp_change')) {
      final change = updates['hp_change'];
      if (change != null && change is int) {
        final newHp = (currentCharacter.currentHp + change)
            .clamp(0, currentCharacter.maxHp);
        await _dao.forceUpdateHp(currentCharacter.id, newHp);
      }
    }

    if (updates.containsKey('gold_change')) {
      final change = updates['gold_change'] as int? ?? 0;
      final newGold = currentCharacter.gold + change;
      await _dao.updateGold(currentCharacter.id, newGold);
    }

    if (updates.containsKey('location_update')) {
      final newLoc = updates['location_update'] as String?;
      if (newLoc != null) {
        await _dao.updateLocation(currentCharacter.id, newLoc);
      }
    }

    if (updates.containsKey('add_items')) {
      final items = updates['add_items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          await _dao.addItem(currentCharacter.id, item as String);
        }
      }
    }

    if (updates.containsKey('remove_items')) {
      final items = updates['remove_items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          await _dao.removeItem(currentCharacter.id, item as String);
        }
      }
    }
  }
}
