import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/features/creation/logic/creation_state.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';
import 'package:ttrpg_sim/core/models/rules/spell_model.dart';

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
      expect(state.remainingTraitPoints, 3);
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
      expect(state.remainingTraitPoints, 1); // 3 - 2 = 1
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
      expect(state.remainingTraitPoints, 5); // 3 - (-2) = 5
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
      expect(state.remainingTraitPoints, 3);
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
      expect(container.read(creationProvider).remainingTraitPoints, 1);

      // Remove
      notifier.toggleTrait(trait);

      final state = container.read(creationProvider);
      expect(state.selectedTraits, isEmpty);
      expect(state.remainingTraitPoints, 3);
    });

    test('Origin selection adds skills and feats', () {
      final notifier = container.read(creationProvider.notifier);
      final origin = OriginDef(
        name: 'Scholar',
        genre: 'Fantasy',
        skills: ['Arcana'],
        feats: ['Arcane Initiate'],
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

      notifier.setOrigin(origin, [feat]);

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

    group('Magic Pillar Logic', () {
      test('Generic Unlock allows all pillars (null)', () {
        final notifier = container.read(creationProvider.notifier);
        final trait = TraitDef(
            name: 'Gifted',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: 'Magic',
            effect: 'Unlock Magic');
        notifier.toggleTrait(trait);
        expect(container.read(creationProvider).allowedPillars, isNull);
      });

      test('Specific Unlock restricts pillars', () {
        final notifier = container.read(creationProvider.notifier);
        final trait = TraitDef(
            name: 'Cosmic Soul',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: 'Cosmos',
            effect: 'Unlock Magic (Pillar: Cosmos)');
        notifier.toggleTrait(trait);

        final allowed = container.read(creationProvider).allowedPillars;
        expect(allowed, isNotNull);
        expect(allowed, contains('Cosmos'));
        expect(allowed!.length, 1);
      });

      test('Multiple Specific traits combine (Union)', () {
        final notifier = container.read(creationProvider.notifier);
        final t1 = TraitDef(
            name: 'Cosmic',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: '',
            effect: 'Pillar: Cosmos');
        final t2 = TraitDef(
            name: 'Druid',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: '',
            effect: 'Pillar: Spirit');

        notifier.toggleTrait(t1);
        notifier.toggleTrait(t2);

        final allowed = container.read(creationProvider).allowedPillars;
        expect(allowed, containsAll(['Cosmos', 'Spirit']));
      });

      test('Generic Unlock overrides Specific restriction', () {
        final notifier = container.read(creationProvider.notifier);
        final specific = TraitDef(
            name: 'Cosmic',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: '',
            effect: 'Pillar: Cosmos');
        final generic = TraitDef(
            name: 'Archmage',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: '',
            effect: 'Unlock Magic');

        notifier.toggleTrait(specific);
        expect(container.read(creationProvider).allowedPillars, isNotNull);

        notifier.toggleTrait(generic);
        expect(container.read(creationProvider).allowedPillars, isNull);
      });

      test('Multi-Pillar String parses correctly', () {
        final notifier = container.read(creationProvider.notifier);
        final trait = TraitDef(
            name: 'Hybrid',
            type: 'Magic',
            cost: 1,
            genre: 'All',
            description: '',
            effect: 'Pillar: Time/Matter');

        notifier.toggleTrait(trait);

        final allowed = container.read(creationProvider).allowedPillars;
        expect(allowed, containsAll(['Time', 'Matter']));
      });
    });

    group('Spell Selection Logic', () {
      final spell1 = SpellDef(
        name: 'Fireball',
        source: 'Arcane',
        intent: 'Harm',
        tier: 1,
        cost: 0,
        description: 'Boom',
        damageDice: '1d6',
        damageType: 'Fire',
      );
      final spell2 = SpellDef(
        name: 'Heal',
        source: 'Divine',
        intent: 'Utility',
        tier: 1,
        cost: 0,
        description: 'Heals',
        damageDice: '',
        damageType: '',
      );

      test('setGeneratedSpells updates state and clears selected', () {
        final notifier = container.read(creationProvider.notifier);

        notifier.toggleSpell(spell1); // Select one first
        expect(container.read(creationProvider).selectedSpells.length, 1);

        notifier.setGeneratedSpells([spell1, spell2]);

        final state = container.read(creationProvider);
        expect(state.generatedSpells.length, 2);
        expect(state.selectedSpells,
            isEmpty); // Should clear selection on new generation
      });

      test('toggleSpell adds and removes spells', () {
        final notifier = container.read(creationProvider.notifier);

        notifier.toggleSpell(spell1);
        expect(container.read(creationProvider).selectedSpells.length, 1);
        expect(container.read(creationProvider).selectedSpells.first.name,
            'Fireball');

        notifier.toggleSpell(spell1); // Toggle off
        expect(container.read(creationProvider).selectedSpells, isEmpty);

        notifier.toggleSpell(spell2);
        expect(container.read(creationProvider).selectedSpells.length, 1);
        expect(
            container.read(creationProvider).selectedSpells.first.name, 'Heal');
      });
    });
  });
}
