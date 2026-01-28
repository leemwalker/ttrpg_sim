import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

void main() {
  group('CreationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      final state = container.read(creationProvider);
      expect(state.remainingTraitPoints, 2);
      expect(state.selectedTraits, isEmpty);
    });

    test('Adding positive cost trait reduces points', () {
      final notifier = container.read(creationProvider.notifier);

      final trait = TraitDef(
          name: 'Strong',
          type: 'Physical',
          cost: 2,
          genre: 'Universal',
          description: 'Strong',
          effect: 'None');

      notifier.toggleTrait(trait);

      final state = container.read(creationProvider);
      expect(state.selectedTraits, contains(trait));
      expect(state.remainingTraitPoints, 0); // 2 - 2 = 0
    });

    test('Adding negative cost trait increases points', () {
      final notifier = container.read(creationProvider.notifier);

      final trait = TraitDef(
          name: 'Weak',
          type: 'Physical',
          cost: -2,
          genre: 'Universal',
          description: 'Weak',
          effect: 'None');

      notifier.toggleTrait(trait);

      final state = container.read(creationProvider);
      expect(state.selectedTraits, contains(trait));
      expect(state.remainingTraitPoints, 4); // 2 - (-2) = 4
    });

    test('Cannot afford trait', () {
      final notifier = container.read(creationProvider.notifier);

      final trait = TraitDef(
          name: 'Expensive',
          type: 'Titan',
          cost: 5,
          genre: 'Universal',
          description: 'Very Strong',
          effect: 'None');

      notifier.toggleTrait(trait);

      final state = container.read(creationProvider);
      expect(state.selectedTraits, isEmpty);
      expect(state.remainingTraitPoints, 2);
    });

    test('removing trait refunds points', () {
      final notifier = container.read(creationProvider.notifier);

      final trait = TraitDef(
          name: 'Strong',
          type: 'Physical',
          cost: 2,
          genre: 'Universal',
          description: 'Strong',
          effect: 'None');

      // Add first
      notifier.toggleTrait(trait);
      expect(container.read(creationProvider).remainingTraitPoints, 0);

      // Remove
      notifier.toggleTrait(trait);

      final state = container.read(creationProvider);
      expect(state.selectedTraits, isEmpty);
      expect(state.remainingTraitPoints, 2);
    });

    test('Origin selection adds skills and feats', () {
      final notifier = container.read(creationProvider.notifier);
      final origin = OriginDef(
        name: 'Scholar',
        genre: 'Fantasy',
        skills: ['Arcana'],
        feat: 'Arcane Initiate',
        items: ['Book'],
        description: 'Learned',
      );
      final feat = FeatDef(
        name: 'Arcane Initiate',
        genre: 'Fantasy',
        type: 'Magic',
        prerequisite: 'None',
        description: 'Magic',
        effect: 'None',
      );

      notifier.setOrigin(origin, feat);

      final state = container.read(creationProvider);
      expect(state.selectedOrigin, equals(origin));
      expect(state.skillRanks['Arcana'], equals(1));
      expect(
          state.selectedFeats.any((f) => f.name == 'Arcane Initiate'), isTrue);
    });

    test('Unlock logic correctly asserts state', () {
      final notifier = container.read(creationProvider.notifier);

      // Initial check
      expect(notifier.hasTrait('Magic Touched'), isFalse);

      final trait = TraitDef(
          name: 'Magic Touched',
          type: 'Magical',
          cost: 1,
          genre: 'Fantasy',
          description: 'Cast spells',
          effect: 'Unlock Magic');

      notifier.toggleTrait(trait);

      expect(notifier.hasTrait('Magic Touched'), isTrue);
    });
  });
}
