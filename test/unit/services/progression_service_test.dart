import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/features/character/services/progression_service.dart';
import '../mocks.mocks.dart';

// Helper to create dummy character
CharacterData createDummyChar({
  int id = 1,
  int xp = 0,
  int level = 1,
  int hp = 10,
  int con = 10,
  String traits = '[]',
  String feats = '[]',
}) {
  return CharacterData(
    id: id,
    worldId: 1,
    location: 'Loc',
    name: 'Hero',
    species: 'Human',
    background: 'Soldier',
    level: level,
    currentHp: hp,
    maxHp: hp,
    strength: 10,
    dexterity: 10,
    constitution: con,
    intelligence: 10,
    wisdom: 10,
    charisma: 10,
    gold: 0,
    inventory: '[]',
    origin: 'Unknown',
    attributes: '{}',
    skills: '{}',
    traits: traits,
    feats: feats,
    spells: '[]',
    currentMana: 0,
    maxMana: 10,
    armorClass: 10,
    equipment: '{}',
    xp: xp,
    hand: '[]',
    discardPile: '[]',
  );
}

void main() {
  late MockGameDao mockDao;
  late ProgressionService service;

  setUp(() {
    mockDao = MockGameDao();
    service = ProgressionService(mockDao);
  });

  group('XP Thresholds', () {
    test('calculate correct XP for levels', () {
      expect(XpThresholds.xpForLevel(1), 0);
      expect(XpThresholds.xpForLevel(2), 300);
      expect(XpThresholds.xpForLevel(3), 600);
      expect(XpThresholds.xpForLevel(4), 1000);
      expect(XpThresholds.xpForLevel(5), 1500);
      expect(XpThresholds.xpForLevel(6), 2000); // 1000 + (2*500)
    });
  });

  group('HP Calculation', () {
    final allTraits = [
      TraitDef(
          name: 'Hardy',
          type: 'Universal',
          cost: 2,
          genre: 'Universal',
          description: '',
          effect: '+1 Max HP per Level'),
      TraitDef(
          name: 'Frail',
          type: 'Universal',
          cost: -2,
          genre: 'Universal',
          description: '',
          effect: '-1 Max HP per Level'),
    ];
    final allFeats = [
      FeatDef(
          name: 'Ironclad',
          genre: 'Fantasy',
          type: 'General',
          prerequisite: '',
          description: '',
          effect: '+1 HP per level'),
    ];

    test('calculate HP with no traits/feats', () {
      final hp = service.calculateMaxHp(
        level: 1,
        constitution: 10, // Mod 0
        traits: [],
        feats: [],
        allTraits: allTraits,
        allFeats: allFeats,
      );
      // Formula: Level * (8 + ConMod) = 1 * 8 = 8
      expect(hp, 8);
    });

    test('calculate HP with Con Mod', () {
      final hp = service.calculateMaxHp(
        level: 1,
        constitution: 14, // Mod +2
        traits: [],
        feats: [],
        allTraits: allTraits,
        allFeats: allFeats,
      );
      // 1 * (8 + 2) = 10
      expect(hp, 10);
    });

    test('calculate HP with Traits', () {
      final hp = service.calculateMaxHp(
        level: 2,
        constitution: 10,
        traits: ['Hardy'],
        feats: [],
        allTraits: allTraits,
        allFeats: allFeats,
      );
      // 2 * (8 + 0 + 1) = 18
      expect(hp, 18);
    });

    test('calculate HP with Traits and Feats', () {
      final hp = service.calculateMaxHp(
        level: 3,
        constitution: 10,
        traits: ['Hardy'],
        feats: ['Ironclad'],
        allTraits: allTraits,
        allFeats: allFeats,
      );
      // 3 * (8 + 0 + 1 + 1) = 30
      expect(hp, 30);
    });
  });

  group('Level Up Logic', () {
    test('awardXp updates XP and returns false if no level up', () async {
      final char = createDummyChar(xp: 0, level: 1);

      when(mockDao.getCharacterById(1)).thenAnswer((_) async => char);
      when(mockDao.updateXp(1, 100)).thenAnswer((_) async => Future.value());

      final result = await service.awardXp(1, 100);

      verify(mockDao.updateXp(1, 100)).called(1);
      expect(result, false);
    });

    test('awardXp returns true if level up threshold reached', () async {
      // Level 2 requires 300 XP. Current 200 + 100 = 300.
      final char = createDummyChar(xp: 200, level: 1);

      when(mockDao.getCharacterById(1)).thenAnswer((_) async => char);
      when(mockDao.updateXp(1, 300)).thenAnswer((_) async => Future.value());

      final result = await service.awardXp(1, 100);

      expect(result, true);
    });
  });
}
