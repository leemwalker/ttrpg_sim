import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

void main() {
  group('Strict CSV Parsing', () {
    test('ItemDef should throw FormatException on malformed/shifted columns',
        () {
      // "Smart Glasses" row with UNQUOTED properties lists, causing shift.
      // Index 6 should be Cost (100), but due to "HUD,Recording,Zoom", index 6 becomes "Recording".
      final List<dynamic> brokenRow = [
        'Smart Glasses',
        'Cyberpunk',
        'Gear',
        '',
        '',
        'HUD',
        'Recording',
        'Zoom',
        '100',
        'Eyewear with data overlay.',
        ''
      ];

      expect(() => ItemDef.fromCsv(brokenRow), throwsA(isA<FormatException>()),
          reason:
              'Should throw because Cost column contains "Recording" which is not an int');
    });

    test('ItemDef should parse correctly quoted row', () {
      // Fixed row
      final List<dynamic> fixedRow = [
        'Smart Glasses',
        'Cyberpunk',
        'Gear',
        '',
        '',
        'HUD,Recording,Zoom',
        100,
        'Eyewear with data overlay.',
        '',
        '',
        ''
      ];

      final item = ItemDef.fromCsv(fixedRow);
      expect(item.name, 'Smart Glasses');
      expect(item.properties, 'HUD,Recording,Zoom');
      expect(item.cost, 100);
    });
  });
}
