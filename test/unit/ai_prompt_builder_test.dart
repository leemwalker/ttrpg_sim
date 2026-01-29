import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/services/ai_prompt_builder.dart';
import 'package:ttrpg_sim/core/database/database.dart';
// ignore: unused_import
import 'package:ttrpg_sim/features/campaign/data/models/character.dart';

void main() {
  group('AIPromptBuilder', () {
    const testPlayer = CharacterData(
      id: 1,
      name: 'Tester',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 100,
      location: 'TestLoc',
      worldId: 1,
      species: 'Human',
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 16,
      wisdom: 10,
      charisma: 10,
      inventory: '[]', // JSON string in DB
      background: 'Sage',
      backstory: 'A long story',
      origin: 'Unknown',
      attributes: '{}',
      skills: '{}',
      traits: '[]',
      feats: '[]',
      spells: '[]',
      currentMana: 0,
      maxMana: 10,
    );

    test('buildContextPrompt formats status and inventory correctly', () {
      final prompt = AIPromptBuilder.buildContextPrompt(
        "Hello World",
        testPlayer,
        [
          const InventoryData(
            id: 1,
            characterId: 1,
            itemName: "Wand",
            quantity: 1,
          )
        ],
      );

      expect(prompt, contains("Current Status: HP 10/10"));
      expect(prompt, contains("Location: TestLoc"));
      expect(prompt, contains("Gold: 100"));
      expect(prompt, contains("Wand (x1)"));
      expect(prompt, contains("User Action: Hello World"));
    });

    test('buildContextPrompt includes world knowledge when provided', () {
      final prompt = AIPromptBuilder.buildContextPrompt(
        "Look at NPC",
        testPlayer,
        [],
        worldKnowledge: "NPC info here",
      );

      expect(prompt, contains("NPC info here"));
      expect(prompt, contains("User Action: Look at NPC"));
    });

    test(
        'buildInstruction generates correct Session Zero prompt (Genesis Mode)',
        () {
      final instruction = AIPromptBuilder.buildInstruction(
        'Fantasy',
        'Dark',
        'A grim world',
        testPlayer,
        features: [],
        spellSlots: {},
        spells: [],
        items: [],
        location: null, // null location implies Genesis Mode
      );

      expect(instruction, contains("MISSION:"));
      expect(instruction, contains("running a Fantasy tabletop RPG"));
      expect(instruction, contains("Tone: Dark"));
      expect(instruction, contains("Goal: Conduct a 'Session Zero'"));
    });

    test('buildInstruction generates correct Atlas prompt (Atlas Mode)', () {
      // Mock Location
      const location = Location(
        id: 1,
        worldId: 1,
        name: "Town",
        description: "A small town",
        type: "Village",
        coordinates: "0,0",
      );

      final instruction = AIPromptBuilder.buildInstruction(
        'Fantasy',
        'Dark',
        'A grim world',
        testPlayer,
        features: [],
        spellSlots: {},
        spells: [],
        items: [],
        location: location,
      );

      expect(instruction, contains("CURRENT LOCATION:"));
      expect(instruction, contains("Name: Town"));
      expect(instruction, contains("Description: A small town"));
    });
  });
}
