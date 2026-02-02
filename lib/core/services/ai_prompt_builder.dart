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
  }) {
    final featuresStr = features.isNotEmpty ? features.join(', ') : 'None';
    final slotsStr = spellSlots.isNotEmpty ? spellSlots.toString() : 'None';
    final spellsStr = spells.isNotEmpty ? spells.join(', ') : 'None';
    final itemsStr = items.isNotEmpty
        ? items.map((e) => '${e.itemName} (x${e.quantity})').join(', ')
        : 'None';

    // Parse Equipment
    String equipmentStr = "None";
    // We try to parse safely even if database.g.dart isn't ready
    try {
      // Accessing player.equipment might fail if field doesn't exist yet,
      // but we are writing correct code for when it does.
      // Assuming player.equipment is available via generation
      // If not, this code is syntactically correct assuming the class has the getter.
      // To be safe with the 'dynamic' nature of mismatched generation, we can't do much.
      // We will write standard access.

      // Note: For now, avoiding jsonDecode here to keep it simple or assuming it works
      // But we want to show Slot: Item
      // Map<String, dynamic> eq = jsonDecode(player.equipment);
      // equipmentStr = eq.entries.map((e) => "${e.key}: ${e.value}").join(", ");
      // Since we can't import jsonDecode here without modifying imports, we check.
      // dart:convert is likely needed.
    } catch (e) {
      // fallback
    }

    // Build location context based on Genesis Mode vs Atlas Mode
    String locationContext;
    if (location == null) {
      // Genesis Mode: Session Zero - ask player where to start
      locationContext = """
CURRENT STATUS:
- Player: ${player.name} (Level ${player.level} ${player.species} ${player.origin})
- Attributes: ${_formatAttributes(player)}
- Location: A quiet conceptual space within the $genre universe. The air is filled with the potential of $tone.

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

    // Simplified equipment string usage via regex or just assume logic elsewhere injected?
    // Actually, let's just stick to "Inventory" for now but add AC.
    // Or better, inject the raw Equipment string if readable.

    return """
You are a Game Master running a $genre tabletop RPG.
Tone: $tone.
World Context: $description.

Player Profile:
- Name: ${player.name}
- Origin: ${player.origin}
- Species: ${player.species}
- Background: ${player.background ?? 'Unknown'}
- Max HP: ${player.maxHp}
- Armor Class: ${player.armorClass}
- Attributes: ${_formatAttributes(player)}

ABILITIES & LIMITS:
- Features & Traits: $featuresStr
- Max Spell Slots: $slotsStr
- Known Spells/Cantrips: $spellsStr
- Equipped: ${_parseEquipment(player.equipment)}
- Inventory: $itemsStr

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
9. Schema:
{
  "narrative": "The story description and dialogue goes here.",
  "state_updates": {
    "hp_change": 0, 
    "gold_change": 0, 
    "add_items": [], 
    "remove_items": [], 
    "location_update": null
  },
  "suggested_actions": [
    {"label": "Force it open", "skill": "Athletics", "attribute": "STR", "difficulty": 15},
    {"label": "Pick the lock", "skill": "Sleight of Hand", "attribute": "DEX", "difficulty": 12},
    {"label": "Find another way", "skill": "Perception", "attribute": "WIS", "difficulty": 10}
  ]
}
10. Style: Be evocative and concise. Do not ask the user to update their sheet; YOU calculate the updates and put them in 'state_updates'.
11. IMPORTANT: Only include 'suggested_actions' when a skill check is required. For simple narrative responses, omit this field or return an empty array.
""";
  }

  static String buildContextPrompt(
    String userMessage,
    CharacterData player,
    List<InventoryData> inventory, {
    String? worldKnowledge,
  }) {
    String contextSummary = "Current Status: ";
    contextSummary += "HP ${player.currentHp}/${player.maxHp}, ";
    contextSummary += "AC ${player.armorClass}, ";
    contextSummary += "Location: ${player.location}, ";
    contextSummary += "Gold: ${player.gold}";
    contextSummary += "\nAttributes: ${_formatAttributes(player)}";

    contextSummary += "\nEquipped: ${_parseEquipment(player.equipment)}";
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
