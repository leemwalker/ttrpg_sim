import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';

import 'mocks.mocks.dart';

// Helper listener class for verifying Riverpod state changes
class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  late MockGeminiService mockGemini;
  late MockGameDao mockDao;
  late ProviderContainer container;
  late Listener<AsyncValue<GameState>> listener;

  // Dummy data
  const worldId = 1;
  const characterId = 1;

  final dummyChar = CharacterData(
    id: characterId,
    worldId: worldId,
    location: 'Start',
    name: 'Hero',
    species: 'Human',
    background: 'Soldier',
    level: 1,
    currentHp: 10,
    maxHp: 10,
    strength: 10,
    dexterity: 10,
    constitution: 10,
    intelligence: 10,
    wisdom: 10,
    charisma: 10,
    gold: 0,
    inventory: '[]',
    origin: 'Unknown',
    attributes: '{}',
    skills: '{}',
    traits: '[]',
    feats: '[]',
    spells: '[]',
    currentMana: 0,
    maxMana: 10,
  );

  final dummyWorld = World(
    id: worldId,
    name: 'Test World',
    genre: 'Fantasy',
    description: 'A test',
    tone: 'Standard',
    genres: '["Fantasy"]',
    createdAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    mockGemini = MockGeminiService();
    mockDao = MockGameDao();
    listener = Listener<AsyncValue<GameState>>();

    container = ProviderContainer(
      overrides: [
        geminiServiceProvider.overrideWithValue(mockGemini),
        gameDaoProvider.overrideWithValue(mockDao),
      ],
    );
    addTearDown(container.dispose);
  });

  group('GameController Logic Tests', () {
    test('Session Zero: Triggers when history is empty', () async {
      // GIVEN: Empty chat history
      when(mockDao.getRecentMessages(any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });

      when(mockDao.getWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyWorld;
      });

      when(mockDao.getCharacterById(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyChar;
      });

      when(mockDao.getInventoryForCharacter(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });

      when(mockGemini.sendMessage(
        any,
        any,
        any,
        genre: anyNamed('genre'),
        tone: anyNamed('tone'),
        description: anyNamed('description'),
        player: anyNamed('player'),
        features: anyNamed('features'),
        spellSlots: anyNamed('spellSlots'),
        spells: anyNamed('spells'),
        location: anyNamed('location'),
        pois: anyNamed('pois'),
        npcs: anyNamed('npcs'),
        worldKnowledge: anyNamed('worldKnowledge'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return TurnResult(
          narrative: 'Welcome to the world.',
          stateUpdates: {},
        );
      });

      when(mockDao.insertMessage(any, any, any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 1;
      });

      // Listen to the provider to trigger build
      container.listen(
        gameControllerProvider(worldId, characterId),
        listener.call,
        fireImmediately: true,
      );

      // Wait for build to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // THEN: Verify Session Zero triggered
      verify(mockGemini.sendMessage(
        "Begin Session Zero",
        any,
        any,
        genre: anyNamed('genre'),
        tone: anyNamed('tone'),
        description: anyNamed('description'),
        player: anyNamed('player'),
        features: anyNamed('features'),
        spellSlots: anyNamed('spellSlots'),
        spells: anyNamed('spells'),
        location: anyNamed('location'),
        pois: anyNamed('pois'),
        npcs: anyNamed('npcs'),
        worldKnowledge: anyNamed('worldKnowledge'),
      )).called(1);
    });

    test('Submit Action: Happy Path', () async {
      // GIVEN: Existing history so Session Zero doesn't trigger
      when(mockDao.getRecentMessages(any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [
          ChatMessage(
              id: 1,
              role: MessageRole.system,
              content: 'Init',
              timestamp: DateTime.now(),
              worldId: worldId,
              characterId: characterId)
        ];
      });

      when(mockDao.insertMessage(any, any, any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 2;
      });

      when(mockDao.getWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyWorld;
      });
      when(mockDao.getCharacterById(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyChar;
      });

      when(mockDao.getLocationsForWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });
      when(mockDao.getNpcsForWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });

      when(mockGemini.sendMessage(
        any,
        any,
        any,
        genre: anyNamed('genre'),
        tone: anyNamed('tone'),
        description: anyNamed('description'),
        player: anyNamed('player'),
        features: anyNamed('features'),
        spellSlots: anyNamed('spellSlots'),
        spells: anyNamed('spells'),
        location: anyNamed('location'),
        pois: anyNamed('pois'),
        npcs: anyNamed('npcs'),
        worldKnowledge: anyNamed('worldKnowledge'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return TurnResult(
          narrative: 'You punch the goblin.',
          stateUpdates: {},
        );
      });

      // Init Listener
      container.listen(
        gameControllerProvider(worldId, characterId),
        listener.call,
        fireImmediately: true,
      );

      // Wait for build
      await Future.delayed(const Duration(milliseconds: 50));

      // Get Notifier
      final controller =
          container.read(gameControllerProvider(worldId, characterId).notifier);

      // WHEN: User submits action
      await controller.submitAction("I punch the goblin");

      // Wait for async cycle
      await Future.delayed(const Duration(milliseconds: 50));

      // THEN: Verify flow
      verify(mockDao.insertMessage('user', "I punch the goblin", any, any))
          .called(1);

      verify(mockGemini.sendMessage(
        "I punch the goblin",
        any,
        any,
        genre: anyNamed('genre'),
        tone: anyNamed('tone'),
        description: anyNamed('description'),
        player: anyNamed('player'),
        features: anyNamed('features'),
        spellSlots: anyNamed('spellSlots'),
        spells: anyNamed('spells'),
        location: anyNamed('location'),
        pois: anyNamed('pois'),
        npcs: anyNamed('npcs'),
        worldKnowledge: anyNamed('worldKnowledge'),
      )).called(1);

      verify(mockDao.insertMessage('ai', 'You punch the goblin.', any, any))
          .called(1);
    });

    test('Submit Action: Network Error Handling', () async {
      // GIVEN: Standard setup
      when(mockDao.getRecentMessages(any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [
          ChatMessage(
              id: 1,
              role: MessageRole.system,
              content: 'Init',
              timestamp: DateTime.now(),
              worldId: worldId,
              characterId: characterId)
        ];
      });
      when(mockDao.insertMessage(any, any, any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 2;
      });

      when(mockDao.getWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyWorld;
      });
      when(mockDao.getCharacterById(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyChar;
      });
      when(mockDao.getLocationsForWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });
      when(mockDao.getNpcsForWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [];
      });

      // FAIL: Gemini throws NetworkException
      when(mockGemini.sendMessage(
        any,
        any,
        any,
        genre: anyNamed('genre'),
        tone: anyNamed('tone'),
        description: anyNamed('description'),
        player: anyNamed('player'),
        features: anyNamed('features'),
        spellSlots: anyNamed('spellSlots'),
        spells: anyNamed('spells'),
        location: anyNamed('location'),
        pois: anyNamed('pois'),
        npcs: anyNamed('npcs'),
        worldKnowledge: anyNamed('worldKnowledge'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw NetworkException('No Internet');
      });

      container.listen(
        gameControllerProvider(worldId, characterId),
        listener.call,
        fireImmediately: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      final controller =
          container.read(gameControllerProvider(worldId, characterId).notifier);

      // WHEN: User submits action
      await controller.submitAction("Hello");
      await Future.delayed(const Duration(milliseconds: 50));

      // THEN: Should insert a system error message
      verify(mockDao.insertMessage(
              'system', argThat(contains('Network Error')), any, any))
          .called(1);
    });

    test('Submit Action: Invalid State Recovery (No Character)', () async {
      // GIVEN: Character returns null mid-flow (deleted?)
      when(mockDao.getRecentMessages(any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [
          ChatMessage(
              id: 1,
              role: MessageRole.system,
              content: 'Init',
              timestamp: DateTime.now(),
              worldId: worldId,
              characterId: characterId)
        ];
      });
      when(mockDao.insertMessage(any, any, any, any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 1;
      });
      when(mockDao.getWorld(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return dummyWorld;
      });

      // Character is null
      when(mockDao.getCharacterById(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return null;
      });

      container.listen(
        gameControllerProvider(worldId, characterId),
        listener.call,
        fireImmediately: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      final controller =
          container.read(gameControllerProvider(worldId, characterId).notifier);

      // WHEN
      await controller.submitAction("Action");
      await Future.delayed(const Duration(milliseconds: 50));

      // THEN: Should catch Exception and log error
      verify(mockDao.insertMessage(
              'system', argThat(contains('Error')), any, any))
          .called(1);
    });
  });
}
