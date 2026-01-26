import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';

// Manual Mocks for Wrapper Interfaces
class MockGenerativeModelWrapper implements GenerativeModelWrapper {
  final MockChatSessionWrapper session;
  MockGenerativeModelWrapper(this.session);

  @override
  ChatSessionWrapper startChat({List<Content>? history}) {
    return session;
  }
}

class MockChatSessionWrapper implements ChatSessionWrapper {
  final Future<GenerateContentResponse> Function(Content content) onSendMessage;
  MockChatSessionWrapper(this.onSendMessage);

  @override
  Future<GenerateContentResponse> sendMessage(Content content) {
    return onSendMessage(content);
  }
}

// Testable Service Subclass
class TestableGeminiService extends GeminiService {
  final GenerativeModelWrapper mockModel;

  TestableGeminiService(super.apiKey, this.mockModel);

  @override
  GenerativeModelWrapper createModel(String instruction) {
    return mockModel;
  }
}

// Dummy GameDao
class MockGameDao extends FakeGameDao {
  @override
  Future<List<InventoryData>> getInventoryForCharacter(int characterId) async {
    return [];
  }
}

// Minimal Fake GameDao base to avoid implementing everything
class FakeGameDao implements GameDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GeminiService Tests', () {
    test('sendMessage throws AIFormatException on malformed JSON', () async {
      final fakeSession = MockChatSessionWrapper((content) async {
        return GenerateContentResponse(
          [
            Candidate(
              Content('model', [TextPart('This is not JSON!')]),
              null,
              null,
              null,
              null,
            )
          ],
          null,
        );
      });
      final fakeModel = MockGenerativeModelWrapper(fakeSession);
      final service = TestableGeminiService('fake_key', fakeModel);

      expect(
        () async => await service.sendMessage(
          'Hello',
          MockGameDao(),
          1,
          genre: 'Fantasy',
          tone: 'Standard',
          description: 'Desc',
          player: const CharacterData(
            id: 1,
            name: 'Hero',
            heroClass: 'Fighter',
            species: 'Human',
            level: 1,
            currentHp: 10,
            maxHp: 10,
            gold: 0,
            location: 'Loc',
            worldId: 1,
            inventory: '[]',
            // Added required stats
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10,
          ),
          features: [],
          spellSlots: {},
          spells: [],
        ),
        throwsA(isA<AIFormatException>()),
      );
    });

    test('sendMessage throws NetworkException on SocketException', () async {
      final fakeSession = MockChatSessionWrapper((content) async {
        throw const SocketException('No Internet');
      });
      final fakeModel = MockGenerativeModelWrapper(fakeSession);
      final service = TestableGeminiService('fake_key', fakeModel);

      expect(
        () async => await service.sendMessage(
          'Hello',
          MockGameDao(),
          1,
          genre: 'Fantasy',
          tone: 'Standard',
          description: 'Desc',
          player: const CharacterData(
            id: 1,
            name: 'Hero',
            heroClass: 'Fighter',
            species: 'Human',
            level: 1,
            currentHp: 10,
            maxHp: 10,
            gold: 0,
            location: 'Loc',
            worldId: 1,
            inventory: '[]',
            // Added required stats
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10,
          ),
          features: [],
          spellSlots: {},
          spells: [],
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
