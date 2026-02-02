import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';

/// Unit tests for Character Creation budget system (Task 5 Audit)
void main() {
  group('Creation Budgets', () {
    test('Easy mode has correct budget values', () {
      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.easy,
      );

      final budgets = state.budgets;
      expect(budgets.pointBuyPoints, 42, reason: 'Easy: 42 point buy');
      expect(budgets.originSkills, 4, reason: 'Easy: 4 origin skills');
      expect(budgets.originFeats, 2, reason: 'Easy: 2 origin feats');
      expect(budgets.traitPoints, 6, reason: 'Easy: 6 trait points');
      expect(budgets.maxAttribute, 18, reason: 'Easy: max attribute 18');
    });

    test('Medium mode has correct budget values', () {
      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.medium,
      );

      final budgets = state.budgets;
      expect(budgets.pointBuyPoints, 28, reason: 'Medium: 28 point buy');
      expect(budgets.originSkills, 3, reason: 'Medium: 3 origin skills');
      expect(budgets.originFeats, 1, reason: 'Medium: 1 origin feat');
      expect(budgets.traitPoints, 3, reason: 'Medium: 3 trait points');
    });

    test('Hard mode has correct budget values', () {
      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.hard,
      );

      final budgets = state.budgets;
      expect(budgets.pointBuyPoints, 19, reason: 'Hard: 19 point buy');
      expect(budgets.originSkills, 2, reason: 'Hard: 2 origin skills');
      expect(budgets.originFeats, 0, reason: 'Hard: 0 origin feats');
      expect(budgets.traitPoints, 1, reason: 'Hard: 1 trait point');
    });

    test('Expert mode has correct budget values', () {
      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.expert,
      );

      final budgets = state.budgets;
      expect(budgets.pointBuyPoints, 12, reason: 'Expert: 12 point buy');
      expect(budgets.originSkills, 1, reason: 'Expert: 1 origin skill');
      expect(budgets.originFeats, 0, reason: 'Expert: 0 origin feats');
      expect(budgets.traitPoints, 1, reason: 'Expert: 1 trait point');
      expect(budgets.maxAttribute, 18, reason: 'Expert: max attribute 18');
    });

    test('Custom mode has unlimited budgets', () {
      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.custom,
      );

      final budgets = state.budgets;
      expect(budgets.pointBuyPoints, 999);
      expect(budgets.originSkills, 99);
      expect(budgets.originFeats, 99);
      expect(budgets.traitPoints, 99);
      expect(budgets.maxAttribute, 30);
    });
  });

  group('Trait Points', () {
    test('remainingTraitPoints decreases with selected traits', () {
      final testTrait = TraitDef(
        name: 'Darkvision',
        type: 'Species',
        cost: 2,
        genre: 'Core',
        description: 'See in darkness',
        effect: 'Can see 60ft in darkness',
      );

      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.medium, // 3 trait points
        selectedTraits: [testTrait],
      );

      // 3 - 2 = 1 remaining
      expect(state.remainingTraitPoints, 1);
    });

    test('negative cost traits increase remaining points', () {
      final flaw = TraitDef(
        name: 'Clumsy',
        type: 'Flaw',
        cost: -1, // Negative cost grants extra points
        genre: 'Core',
        description: 'Poor coordination',
        effect: '-1 to Dexterity checks',
      );

      final state = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.medium, // 3 trait points
        selectedTraits: [flaw],
      );

      // 3 - (-1) = 4 remaining
      expect(state.remainingTraitPoints, 4);
    });
  });

  group('CreationBudgets Values', () {
    test('all difficulty levels have valid max attribute', () {
      for (final difficulty in GameDifficulty.values) {
        if (difficulty == GameDifficulty.custom) continue;

        final state = CharacterCreationState(
          activeGenres: ['Fantasy'],
          difficulty: difficulty,
        );

        expect(state.budgets.maxAttribute, greaterThanOrEqualTo(15),
            reason: '$difficulty should have reasonable max attribute');
        expect(state.budgets.maxAttribute, lessThanOrEqualTo(20),
            reason: '$difficulty should not exceed 20 max attribute');
      }
    });

    test('harder difficulties have fewer points', () {
      final easy = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.easy,
      );
      final expert = CharacterCreationState(
        activeGenres: ['Fantasy'],
        difficulty: GameDifficulty.expert,
      );

      expect(easy.budgets.pointBuyPoints,
          greaterThan(expert.budgets.pointBuyPoints));
      expect(easy.budgets.traitPoints, greaterThan(expert.budgets.traitPoints));
    });
  });
}
