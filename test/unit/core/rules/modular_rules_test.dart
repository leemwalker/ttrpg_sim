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
  group('ModularRulesController Tests', () {
    late ModularRulesController controller;
    late MockRuleDataLoader mockLoader;

    setUp(() {
      controller = ModularRulesController();
      mockLoader = MockRuleDataLoader();

      // Seed Dummy Data
      // Genres
      mockLoader.setResponse('assets/system/Genres.csv',
          'Name,Description,Currency,Key Themes\r\nFantasy,Magic worlds,GP,Magic\r\nSci-Fi,Tech worlds,Credits,Tech');

      // Attributes
      mockLoader.setResponse('assets/system/Attributes.csv',
          'Name,Genre,Type,Description\r\nStrength,Universal,Physical,Power\r\nLogic,Sci-Fi,Mental,Thinking');

      // Skills
      mockLoader.setResponse('assets/system/Skills.csv',
          'Name,Genre,Attribute,Locked?,Description\r\nArcana,Fantasy,INT,FALSE,Magic info\r\nComputers,Sci-Fi,INT,FALSE,Hacking\r\nAthletics,Universal,STR,FALSE,Running');

      // Species
      mockLoader.setResponse('assets/system/Species.csv',
          'Name,Genre,Stats,Free Traits\r\nElf,Fantasy,+2 DEX,Keen Senses\r\nAndroid,Sci-Fi,+2 INT,Constructed\r\nHuman,Universal,+1 All Stats,None');

      // Traits
      mockLoader.setResponse('assets/system/Traits.csv',
          'Name,Type,Cost,Genre,Description,Effect\r\nStrong,Physical,2,Universal,Strong stuff,None\r\nMagic Touched,Magical,3,Fantasy,Cast spells,Unlock Magic\r\nWeak,Physical,-2,Universal,Weak stuff,Refund points');

      // Origins
      mockLoader.setResponse('assets/system/Origins.csv',
          'Name,Genre,Skills,Feat,Starting Items,Description\r\nScholar,Fantasy,Arcana,Arcane Initiate,Book,Studious');

      // Feats
      mockLoader.setResponse('assets/system/Feats.csv',
          'Name,Genre,Type,Prerequisite,Description,Effect\r\nArcane Initiate,Fantasy,Magic,None,Learn magic,Unlock spells');

      // Items
      mockLoader.setResponse('assets/system/Items.csv',
          'Name,Genre,Type,DamageDice,DamageType,Properties,Cost,Description\r\nSword,Fantasy,Weapon,1d8,Slashing,None,10,Sharp\r\nLaser Pistol,Sci-Fi,Weapon,1d6,Energy,Range,50,Pew pew');

      // Magic Pillars
      mockLoader.setResponse('assets/system/MagicPillars.csv',
          'Name,Description,Keywords\r\nMatter,"Physical world","Earth, Water"\r\nEnergy,"Raw forces","Fire, Lightning"\r\nMind,"Thoughts","Telepathy"\r\nSpirit,"Life force","Life, Death"\r\nCosmos,"Space and time","Teleportation"');
    });

    test('Loads rules correctly from CSV', () async {
      await controller.loadRules(loader: mockLoader);

      expect(controller.isLoaded, isTrue);
      expect(controller.allSpecies.length, greaterThanOrEqualTo(3));
      expect(controller.allSkills.length, greaterThanOrEqualTo(3));
    });

    test('getSpecies() filters by Genre', () async {
      await controller.loadRules(loader: mockLoader);

      // Fantasy World checking
      final fantasySpecies = controller.getSpecies(['Fantasy']);
      // Should include Elf (Fantasy) and Human (Universal)
      expect(fantasySpecies.any((s) => s.name == 'Elf'), isTrue);
      expect(fantasySpecies.any((s) => s.name == 'Human'), isTrue);
      // Should NOT include Android (Sci-Fi)
      expect(fantasySpecies.any((s) => s.name == 'Android'), isFalse);

      // Sci-Fi World checking
      final sciFiSpecies = controller.getSpecies(['Sci-Fi']);
      expect(sciFiSpecies.any((s) => s.name == 'Android'), isTrue);
      expect(sciFiSpecies.any((s) => s.name == 'Human'), isTrue);
      expect(sciFiSpecies.any((s) => s.name == 'Elf'), isFalse);
    });

    test('getSkills() filters by Genre', () async {
      await controller.loadRules(loader: mockLoader);

      final fantasySkills = controller.getSkills(['Fantasy']);
      expect(fantasySkills.any((s) => s.name == 'Arcana'), isTrue);
      expect(fantasySkills.any((s) => s.name == 'Athletics'), isTrue);
      expect(fantasySkills.any((s) => s.name == 'Computers'), isFalse);

      final sciFiSkills = controller.getSkills(['Sci-Fi']);
      expect(sciFiSkills.any((s) => s.name == 'Computers'), isTrue);
      expect(sciFiSkills.any((s) => s.name == 'Athletics'), isTrue);
      expect(sciFiSkills.any((s) => s.name == 'Arcana'), isFalse);
    });

    test('getTraits() parses costs correctly', () async {
      await controller.loadRules(loader: mockLoader);

      final traits = controller.getTraits(['Universal', 'Fantasy']);

      final strong = traits.firstWhere((t) => t.name == 'Strong');
      expect(strong.cost, equals(2));

      final weak = traits.firstWhere((t) => t.name == 'Weak');
      expect(weak.cost, equals(-2));
    });
    test('getOrigins() filters by Genre', () async {
      await controller.loadRules(loader: mockLoader);

      final fantasyOrigins = controller.getOrigins(['Fantasy']);
      expect(fantasyOrigins.any((o) => o.name == 'Scholar'), isTrue);

      final sciFiOrigins = controller.getOrigins(['Sci-Fi']);
      expect(sciFiOrigins.any((o) => o.name == 'Scholar'), isFalse);
    });

    test('getFeats() filters by Genre', () async {
      await controller.loadRules(loader: mockLoader);

      final fantasyFeats = controller.getFeats(['Fantasy']);
      expect(fantasyFeats.any((f) => f.name == 'Arcane Initiate'), isTrue);

      final sciFiFeats = controller.getFeats(['Sci-Fi']);
      expect(sciFiFeats.any((f) => f.name == 'Arcane Initiate'), isFalse);
    });

    test('getItems() filters by Genre', () async {
      await controller.loadRules(loader: mockLoader);

      final fantasyItems = controller.getItems(['Fantasy']);
      expect(fantasyItems.any((i) => i.name == 'Sword'), isTrue);
      expect(fantasyItems.any((i) => i.name == 'Laser Pistol'), isFalse);

      final sciFiItems = controller.getItems(['Sci-Fi']);
      expect(sciFiItems.any((i) => i.name == 'Laser Pistol'), isTrue);
      expect(sciFiItems.any((i) => i.name == 'Sword'), isFalse);
    });
  });
}
