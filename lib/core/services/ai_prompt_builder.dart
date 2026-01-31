import 'package:ttrpg_sim/core/database/database.dart';

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

    // Build location context based on Genesis Mode vs Atlas Mode
    String locationContext;
    if (location == null) {
      // Genesis Mode: Session Zero - ask player where to start
      locationContext = """
CURRENT STATUS:
- Player: ${player.name} (Level ${player.level} ${player.species} ${player.origin})
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
- Origin: ${player.origin}
- Species: ${player.species}
- Background: ${player.background ?? 'Unknown'}
- Max HP: ${player.maxHp}

ABILITIES & LIMITS:
- Features & Traits: $featuresStr
- Max Spell Slots: $slotsStr
- Known Spells/Cantrips: $spellsStr
- Inventory: $itemsStr

$locationContext

Rules:
1. Adhere to the Custom Modular D20 System logic (Standard D20 formatting).
2. FIRST and FOREMOST: Narrative the result of the user's requested action (e.g. "You look around...", "You attack the goblin...") BEFORE providing environmental flavor text.
3. If the player attempts to cast a spell NOT in their Known Spells, or of a level higher than they have slots for, reject the action and narrate the failure gracefully.
4. If the player tries to use a class feature NOT in their Class Features, narrate why they cannot do that yet.
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

  static String buildContextPrompt(
    String userMessage,
    CharacterData player,
    List<InventoryData> inventory, {
    String? worldKnowledge,
  }) {
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

    String prompt = "$contextSummary\n\n";
    if (worldKnowledge != null) {
      prompt += "$worldKnowledge\n\n";
    }
    prompt += "User Action: $userMessage\n";

    return prompt;
  }
}
