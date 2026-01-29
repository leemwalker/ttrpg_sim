import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

void main() {
  group('Content Integrity', () {
    test('Attributes.csv should load all Core and Genre attributes', () async {
      final rows = await _loadCsv('assets/system/MobileRPG - Attributes.csv');
      // Should have 6 Core + ~25 Genre attributes = ~31 rows.
      // Definitively more than 2.
      expect(rows.length, greaterThan(20),
          reason:
              'Attributes CSV parsed too few rows, likely header/quote swallow bug.');

      // Verify random check
      final conRow = rows.firstWhere((r) => r[0].toString() == 'Constitution',
          orElse: () => []);
      expect(conRow, isNotEmpty, reason: 'Constitution row missing');
    });

    test('Traits.csv should load all initial traits', () async {
      final rows = await _loadCsv('assets/system/MobileRPG - Traits.csv');
      expect(rows.length, greaterThan(15),
          reason: 'Traits CSV parsed too few rows');

      final luckyRow =
          rows.firstWhere((r) => r[0].toString() == 'Blind', orElse: () => []);
      expect(luckyRow, isNotEmpty, reason: 'Blind trait (end of file) missing');
    });

    test('Skills.csv should load all skills', () async {
      final rows = await _loadCsv('assets/system/MobileRPG - Skills.csv');
      expect(rows.length, greaterThan(50),
          reason: 'Skills CSV parsed too few rows');
    });
  });
}

Future<List<List<dynamic>>> _loadCsv(String path) async {
  final file = File(path);
  if (!await file.exists()) fail('Asset not found: $path');
  final content = await file.readAsString();
  List<List<dynamic>> rows =
      const CsvToListConverter(shouldParseNumbers: false).convert(content);
  if (rows.isNotEmpty) rows = rows.sublist(1); // Skip Header
  return rows;
}
