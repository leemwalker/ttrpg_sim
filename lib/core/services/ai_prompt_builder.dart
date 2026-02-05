import 'dart:convert';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

class AIPromptBuilder {
  static String buildInstruction(
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
    String system = 'd20', // 'd20' or 'imagin8'
  }) {
    if (system == 'imagin8') {
      return _buildImagin8Instruction(
          genre, tone, description, player, features, location, pois, npcs);
    }

    final featuresStr = features.isNotEmpty ? features.join(', ') : 'None';
    // ... (rest of d20 logic)
    final slotsStr = spellSlots.isNotEmpty ? spellSlots.toString() : 'None';
    final spellsStr = spells.isNotEmpty ? spells.join(', ') : 'None';
    final itemsStr = items.isNotEmpty
        ? items.map((e) => '${e.itemName} (x${e.quantity})').join(', ')
        : 'None';

    // Build location context based on Genesis Mode vs Atlas Mode
    String locationContext;
    if (location == null) {
      // ... (existing genesis logic)
      locationContext =
          "CURRENT STATUS:\n- Player: ${player.name} (Level ${player.level} ${player.species} ${player.origin})\n- Location: Genesis/Session Zero.";
    } else {
      // ... (existing atlas logic)
      final poisStr =
          pois.isEmpty ? 'None visible' : pois.map((p) => p.name).join(', ');
      final npcsStr = npcs.isEmpty
          ? 'None visible'
          : npcs.map((n) => '${n.name} (${n.role})').join(', ');
      locationContext =
          "CURRENT LOCATION:\n- Name: ${location.name}\n- Description: ${location.description}\n- POIs: $poisStr\n- NPCs: $npcsStr";
    }

    return """
You are a Game Master running a $genre tabletop RPG.
Tone: $tone.
World Context: $description.

Player Profile:
- Name: ${player.name}
- Level: ${player.level}
- Species: ${player.species}
- Class/Origin: ${player.origin}
- HP: ${player.currentHp}/${player.maxHp}
- AC: ${player.armorClass}
- Attributes: ${_formatAttributes(player)}

CONTEXT:
Features: $featuresStr
Spells: $spellsStr (Slots: $slotsStr)
Inventory: $itemsStr
Equipped: ${_parseEquipment(player.equipment)}

$locationContext

Rules:
1. Adhere to the Custom Modular D20 System logic (Standard D20 formatting).
2. FIRST and FOREMOST: Narrative the result of the user's requested action (e.g. "You look around...", "You attack the goblin...") BEFORE providing environmental flavor text.
3. If the player attempts to cast a spell NOT in their Known Spells, or of a level higher than they have slots for, reject the action and narrate the failure gracefully.
4. If the player tries to use a class feature NOT in their Class Features, narrate why they cannot do that yet.
5. RULE: You are a Game Master. If the user attempts an action that is difficult or has a chance of failure, you MUST ask for a Dice Roll or use the [Roll Dice] tool. Do not simply grant success for complex tasks.
6. LITRPG FORMATTING: When narrating State Updates (e.g. HP loss, XP gain, Item drops), format them distinctly using [Blue Brackets] or **Bold Text** to mimic a system notification.
7. SKILL CHECK OPTIONS: When the player attempts a complex action that could be approached multiple ways (e.g., opening a locked door, convincing a guard, bypassing a trap), provide EXACTLY 3 distinct approaches in the 'suggested_actions' array. Each option should use a different skill/attribute combination. Do NOT include suggested_actions for simple narrative responses or combat actions.
8. Output Format: You must ALWAYS return valid JSON.
9. Match the exact schema defined in the tool definition.
10. Style: Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
11. IMPORTANT: Only include 'suggested_actions' when a skill check is required. For simple narrative responses, omit this field or return an empty array.
""";
  }

  static String _buildImagin8Instruction(
    String genre,
    String tone,
    String description,
    CharacterData player,
    List<String> features,
    Location? location,
    List<PointsOfInterestData> pois,
    List<Npc> npcs,
  ) {
    String locationContext;
    if (location == null) {
      locationContext = "Location: Session Zero (Genesis)";
    } else {
      final poisStr =
          pois.isEmpty ? 'None visible' : pois.map((p) => p.name).join(', ');
      final npcsStr = npcs.isEmpty
          ? 'None visible'
          : npcs.map((n) => '${n.name} (${n.role})').join(', ');
      locationContext =
          "CURRENT LOCATION:\n- Name: ${location.name}\n- Description: ${location.description}\n- POIs: $poisStr\n- NPCs: $npcsStr";
    }

    return """
SYSTEM: Imagin8 Narrative Dice System
GENRE: $genre
TONE: $tone
WORLD CONTEXT: $description

PLAYER: ${player.name} (${player.species} ${player.origin})
$locationContext

RESOLUTION MECHANIC: 
- Player rolls 1d8. 
- 1-4: Failure or Complication.
- 5-7: Success.
- 8: Critical Success / Recover Card.
- Do NOT use DC (Difficulty Class). Do NOT ask for Attribute checks (STR/DEX etc).
- Instead, prompt for a "Risk Roll" (d8) when the outcome is uncertain.

CARD MECHANIC:
- Players use Cards significantly to influence the story.
- If a player uses a card (indicated in their action), incorporate its description and tag effects into the narrative.
- If a player is "Out of Hand", they are vulnerable.

GM ROLE:
- Focus on narrative consequences.
- Be evocative.
- Use the provided location and NPC context to drive the scene.
- Output JSON format as specified in the schema.
- When introducing a new NPC, Enemy, or Item, use the `consult_deck` tool to find a matching card from the database. Do not invent mechanical stats; use the cards.
- If the player rolls a 1 (Complication), you may use `consult_deck(type: 'Drawback')` to find a thematic consequence.
""";
  }

  static String buildContextPrompt(
    String userMessage,
    CharacterData player,
    List<InventoryData> inventory, {
    String? worldKnowledge,
    List<Imagin8Card> hand = const [],
    List<Imagin8Card> discard = const [],
  }) {
    String contextSummary = "Current Status: ";
    contextSummary += "HP ${player.currentHp}/${player.maxHp}, ";
    contextSummary += "Gold: ${player.gold}";
    // Attributes are less relevant in Imagin8 but kept for context if mixed
    // contextSummary += "\nAttributes: ${_formatAttributes(player)}";

    // Add Hand Context for Imagin8
    if (hand.isNotEmpty) {
      contextSummary += "\n\n[PLAYER HAND (AVAILABLE RESOURCES)]\n";
      for (final card in hand) {
        contextSummary +=
            "* ${card.name} (${card.type}): ${card.description} [Mechanic: ${card.mechanic}]\n";
      }
    }

    if (discard.isNotEmpty) {
      contextSummary += "\n[DISCARD PILE (RECENTLY USED)]\n";
      contextSummary += discard.map((c) => c.name).join(", ");
      contextSummary += "\n";
    }

    // Regular Inventory
    contextSummary += "\nInventory: ";
    if (inventory.isNotEmpty) {
      contextSummary +=
          inventory.map((e) => "${e.itemName} (x${e.quantity})").join(', ');
    } else {
      contextSummary += "Empty";
    }

    String prompt = "$contextSummary\n\n";
    if (worldKnowledge != null) {
      prompt += "$worldKnowledge\n\n";
    }
    prompt += "User Action: $userMessage\n";

    return prompt;
  }

  static String _formatAttributes(CharacterData p) {
    String mod(int score) {
      final m = ((score - 10) / 2).floor();
      return m >= 0 ? '+$m' : '$m';
    }

    return "STR ${p.strength} (${mod(p.strength)}), "
        "DEX ${p.dexterity} (${mod(p.dexterity)}), "
        "CON ${p.constitution} (${mod(p.constitution)}), "
        "INT ${p.intelligence} (${mod(p.intelligence)}), "
        "WIS ${p.wisdom} (${mod(p.wisdom)}), "
        "CHA ${p.charisma} (${mod(p.charisma)})";
  }

  /// Parses equipment JSON and returns a formatted string with damage dice for weapons.
  /// Example: "Main Hand: Longsword (1d8), Body: Leather Armor (AC +2)"
  static String _parseEquipment(String jsonStr) {
    if (jsonStr == '{}' || jsonStr.isEmpty) return "None";

    try {
      final Map<String, dynamic> equipment = jsonDecode(jsonStr);
      if (equipment.isEmpty) return "None";

      final rules = ModularRulesController();
      final parts = <String>[];

      for (final entry in equipment.entries) {
        final slotName = _formatSlotName(entry.key);
        final itemName = entry.value.toString();
        final itemDef = rules.getItem(itemName);

        if (itemDef != null) {
          String itemInfo = itemName;
          if (itemDef.damageDice.isNotEmpty && itemDef.damageDice != '-') {
            itemInfo += " (${itemDef.damageDice})";
          } else if (itemDef.armorClassBonus != null &&
              itemDef.armorClassBonus! > 0) {
            itemInfo += " (AC +${itemDef.armorClassBonus})";
          }
          parts.add("$slotName: $itemInfo");
        } else {
          parts.add("$slotName: $itemName");
        }
      }

      return parts.join(", ");
    } catch (e) {
      // Fallback to simple string cleaning
      return jsonStr
          .replaceAll('"', '')
          .replaceAll('{', '')
          .replaceAll('}', '');
    }
  }

  /// Converts slot key to readable name (mainHand -> Main Hand)
  static String _formatSlotName(String slot) {
    switch (slot) {
      case 'mainHand':
        return 'Main Hand';
      case 'offHand':
        return 'Off Hand';
      case 'body':
        return 'Body';
      case 'head':
        return 'Head';
      case 'accessory':
        return 'Accessory';
      default:
        return slot[0].toUpperCase() + slot.substring(1);
    }
  }
}
