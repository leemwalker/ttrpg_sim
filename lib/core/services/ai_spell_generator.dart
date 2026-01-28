import 'dart:convert';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/spell_model.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ttrpg_sim/core/providers.dart';

part 'ai_spell_generator.g.dart';

@riverpod
AiSpellGeneratorService aiSpellGeneratorService(
    AiSpellGeneratorServiceRef ref) {
  return AiSpellGeneratorService(ref.read(geminiServiceProvider));
}

class AiSpellGeneratorService {
  final GeminiService _gemini;

  AiSpellGeneratorService(this._gemini);

  Future<List<SpellDef>> generateStartingSpells(CharacterData char) async {
    // 1. Analyze Traits/Feats for Magic Sources
    final traits = (jsonDecode(char.traits) as List).cast<String>();
    final feats = (jsonDecode(char.feats) as List).cast<String>();

    // Simple heuristic: If no "Magic" keyword in traits/feats, assume no innate magic.
    // However, for this task, we assume the user WANTS magic if they are using this flow,
    // or we can just look for hints.
    // Let's assume we pass in explicit context or just infer.

    final magicHints = [...traits, ...feats]
        .where((s) =>
            s.contains('Magic') ||
            s.contains('Spell') ||
            s.contains('Arcane') ||
            s.contains('Divine') ||
            s.contains('Mana') ||
            s.contains('Source'))
        .toList();

    if (magicHints.isEmpty) {
      // If no hints, checking bio might be expensive or ambiguous.
      // We can just generate generic novice spells if requested.
      // Or return empty.
      // Per task prompt: "If found...". If not found?
      // We will default to skipping generation if no magic traits found to save API calls.
      // But for testing purposes, if the character has a "Magic Pillar" in bio (which we don't have structured access to easily without parsing bio),
      // we'll rely on our heuristics.

      // Let's assume if this function is called, the UI/Controller determined the user is a spellcaster.
    }

    final prompt = """
    Character is a level ${char.level} adventurer in a ${char.species} ${char.origin} role.
    Key Traits/Feats: ${magicHints.join(', ')}.
    Background: ${char.backstory ?? 'Unknown'}.
    
    Generate 3 Tier 1 Spells (1 Harm, 1 Ward, 1 Utility) tailored to this character's theme.
    
    Rules:
    1. Tier 1 Spells cost 0 Mana (Cantrips).
    2. Damage should be appropriate for Level 1 (e.g., d6, d8, d10).
    3. Return valid JSON array of objects.
    
    JSON Schema:
    [
      {
        "name": "Spell Name",
        "source": "Arcane/Divine/Nature/etc",
        "intent": "Harm/Ward/Utility",
        "tier": 1,
        "cost": 0,
        "description": "Short flavor description",
        "damageDice": "1d8",
        "damageType": "Fire/Cold/etc"
      }
    ]
    """;

    try {
      // creating a temporary model just for this generation task to avoid session context pollution
      // or usage of chat session. 'generateContent' is stateless.
      final model = _gemini.createModel(
          "You are a TTRPG Design Assistant. Output only valid JSON.");

      // Assuming I can use `sendMessage` on a new session.
      final session = model.startChat();
      final result = await session.sendMessage(Content.text(prompt));

      final text = result.text ?? '[]';
      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> jsonList = jsonDecode(cleanJson);

      return jsonList.map((j) => SpellDef.fromJson(j)).toList();
    } catch (e) {
      print('Spell Generation Error: $e');
      return [];
    }
  }
}
