import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

// Mock Implementation
class MockRuleDataLoader implements RuleDataLoader {
  final Map<String, String> _data = {};

  void setResponse(String path, String content) {
    _data[path] = content;
  }

  @override
  Future<String> load(String path) async {
    if (_data.containsKey(path)) {
      return _data[path]!;
    }
    throw Exception('Asset not found: $path');
  }
}

void main() {
  group('Magic Pillars Tests', () {
    late ModularRulesController controller;
    late MockRuleDataLoader mockLoader;

    setUp(() {
      controller = ModularRulesController();
      mockLoader = MockRuleDataLoader();

      // Seed minimum required CSVs
      mockLoader.setResponse('assets/system/Genres.csv',
          'Name,Description,Currency,Key Themes\r\nFantasy,Magic worlds,GP,Magic');
      mockLoader.setResponse('assets/system/Attributes.csv',
          'Name,Genre,Type,Description\r\nStrength,Universal,Physical,Power');
      mockLoader.setResponse('assets/system/Skills.csv',
          'Name,Genre,Attribute,Locked?,Description\r\nArcana,Fantasy,INT,TRUE,Magic info');
      mockLoader.setResponse('assets/system/Species.csv',
          'Name,Genre,Stats,Free Traits\r\nHuman,Universal,+1 All Stats,None');
      mockLoader.setResponse('assets/system/Traits.csv',
          'Name,Type,Cost,Genre,Description,Effect');
      mockLoader.setResponse('assets/system/Origins.csv',
          'Name,Genre,Skills,Feat,Starting Items,Description');
      mockLoader.setResponse('assets/system/Feats.csv',
          'Name,Genre,Type,Prerequisite,Description,Effect');
      mockLoader.setResponse('assets/system/Items.csv',
          'Name,Genre,Type,DamageDice,DamageType,Properties,Cost,Description');

      // Magic Pillars CSV
      mockLoader.setResponse(
          'assets/system/MagicPillars.csv',
          'Name,Description,Keywords\r\n'
              'Matter,"Manipulation of physical substances","Earth, Water, Metal"\r\n'
              'Energy,"Control of raw forces","Fire, Lightning, Kinetic"\r\n'
              'Mind,"Manipulation of thoughts and perception","Telepathy, Illusion, Memory"\r\n'
              'Spirit,"Connection to life force and souls","Life, Death, Healing"\r\n'
              'Cosmos,"Manipulation of space and time","Teleportation, Gravity, Time"');
    });

    test('Loads all 5 Universal Pillars', () async {
      await controller.loadRules(loader: mockLoader);

      expect(controller.isLoaded, isTrue);
      expect(controller.allPillars.length, equals(5));
    });

    test('Pillars have correct names', () async {
      await controller.loadRules(loader: mockLoader);

      final names = controller.allPillars.map((p) => p.name).toList();
      expect(
          names, containsAll(['Matter', 'Energy', 'Mind', 'Spirit', 'Cosmos']));
    });

    test('Pillars have descriptions', () async {
      await controller.loadRules(loader: mockLoader);

      for (var pillar in controller.allPillars) {
        expect(pillar.description, isNotEmpty,
            reason: '${pillar.name} should have a description');
      }
    });

    test('Pillars have keywords', () async {
      await controller.loadRules(loader: mockLoader);

      for (var pillar in controller.allPillars) {
        expect(pillar.keywords, isNotEmpty,
            reason: '${pillar.name} should have keywords');
      }

      // Specific keyword checks
      final matter =
          controller.allPillars.firstWhere((p) => p.name == 'Matter');
      expect(matter.keywords, contains('Earth'));

      final energy =
          controller.allPillars.firstWhere((p) => p.name == 'Energy');
      expect(energy.keywords, contains('Fire'));
    });

    test('Handles empty MagicPillars.csv gracefully', () async {
      mockLoader.setResponse('assets/system/MagicPillars.csv',
          'Name,Description,Keywords\r\n'); // Empty data, only header

      await controller.loadRules(loader: mockLoader);

      expect(controller.isLoaded, isTrue);
      expect(controller.allPillars, isEmpty);
    });
  });
}
