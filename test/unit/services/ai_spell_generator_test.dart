import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';
import 'package:ttrpg_sim/core/services/ai_spell_generator.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';

// Mocks
// We can't rely on generated mocks for the wrappers easily without running build_runner,
// so we use manual mocks or Mockito's Mock class here.

class MockGeminiService extends Mock implements GeminiService {
  @override
  GenerativeModelWrapper createModel(String? instruction) {
    return super.noSuchMethod(
      Invocation.method(#createModel, [instruction]),
      returnValue: MockGenerativeModelWrapper(),
    ) as GenerativeModelWrapper;
  }
}

class MockGenerativeModelWrapper extends Mock
    implements GenerativeModelWrapper {
  @override
  ChatSessionWrapper startChat({List<Content>? history}) {
    return super.noSuchMethod(
      Invocation.method(#startChat, [], {#history: history}),
      returnValue: MockChatSessionWrapper(),
    ) as ChatSessionWrapper;
  }
}

class MockChatSessionWrapper extends Mock implements ChatSessionWrapper {
  @override
  Future<GenerateContentResponse> sendMessage(Content? content) {
    return super.noSuchMethod(
      Invocation.method(#sendMessage, [content]),
      returnValue: Future.value(GenerateContentResponse([], null)),
    ) as Future<GenerateContentResponse>;
  }
}

void main() {
  late MockGeminiService mockGemini;
  late MockGenerativeModelWrapper mockModel;
  late MockChatSessionWrapper mockSession;
  late AiSpellGeneratorService service;

  setUp(() {
    mockGemini = MockGeminiService();
    mockModel = MockGenerativeModelWrapper();
    mockSession = MockChatSessionWrapper();
    service = AiSpellGeneratorService(mockGemini);

    // Setup Mock Chain
    when(mockGemini.createModel(any)).thenReturn(mockModel);
    when(mockModel.startChat(history: anyNamed('history')))
        .thenReturn(mockSession);
  });

  test('generateStartingSpells returns parsed spells', () async {
    // GIVEN
    final char = CharacterData(
        id: 1,
        name: 'Merlin',
        species: 'Human',
        origin: 'Mage',
        traits: '["Magic Touched"]',
        feats: '[]',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 10,
        location: 'Tower',
        worldId: 1,
        attributes: '{}',
        skills: '{}',
        inventory: '[]',
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
        spells: '[]',
        currentMana: 0,
        maxMana: 10);

    const jsonOutput = '''
    [
      {
        "name": "Firebolt",
        "source": "Arcane",
        "intent": "Harm",
        "tier": 1,
        "cost": 0,
        "description": "Shoots fire",
        "damageDice": "1d10",
        "damageType": "Fire"
      },
      {
         "name": "Shield",
         "source": "Arcane",
         "intent": "Ward",
         "tier": 1,
         "cost": 0,
         "description": "Blocks attacks",
         "damageDice": null,
         "damageType": null
      }
    ]
    ''';

    final candidate =
        Candidate(Content.text(jsonOutput), null, null, null, null);
    final response = GenerateContentResponse([candidate], null);

    when(mockSession.sendMessage(any)).thenAnswer((_) async => response);

    // WHEN
    final spells = await service.generateStartingSpells(char);

    // THEN
    expect(spells.length, 2);
    expect(spells[0].name, 'Firebolt');
    expect(spells[0].damageDice, '1d10');
    expect(spells[1].name, 'Shield');
    expect(spells[1].intent, 'Ward');
  });

  test('generateStartingSpells handles generic trait matching', () async {
    // GIVEN - Has "Arcane" in traits
    final char = CharacterData(
        id: 1,
        name: 'Merlin',
        species: 'Human',
        origin: 'Mage',
        traits: '["Arcane Scholar"]',
        feats: '[]',
        level: 1,
        currentHp: 10,
        maxHp: 10,
        gold: 10,
        location: 'Tower',
        worldId: 1,
        attributes: '{}',
        skills: '{}',
        inventory: '[]',
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
        spells: '[]',
        currentMana: 0,
        maxMana: 10);

    // Mock response
    final candidate = Candidate(Content.text('[]'), null, null, null, null);
    final response = GenerateContentResponse([candidate], null);

    when(mockSession.sendMessage(any)).thenAnswer((_) async => response);

    // WHEN
    await service.generateStartingSpells(char);

    // THEN
    verify(mockModel.startChat()).called(1);
  });
}
