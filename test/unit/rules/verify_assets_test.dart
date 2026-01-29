import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/models/rules/rule_models.dart';

void main() {
  group('System Assets Integrity', () {
    test('All CSVs should parse without error', () async {
      final files = [
        'assets/system/MobileRPG - Genres.csv',
        'assets/system/MobileRPG - Attributes.csv',
        'assets/system/MobileRPG - Skills.csv',
        'assets/system/MobileRPG - Species.csv',
        'assets/system/MobileRPG - Traits.csv',
        'assets/system/MobileRPG - Origins.csv',
        'assets/system/MobileRPG - Feats.csv',
        'assets/system/MobileRPG - Items.csv',
      ];

      for (final path in files) {
        final file = File(path);
        if (!await file.exists()) {
          fail('Asset not found: $path');
        }

        final content = await file.readAsString();
        List<List<dynamic>> rows =
            const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
                .convert(content);

        // Skip header
        if (rows.isNotEmpty) rows = rows.sublist(1);

        print('Verifying $path (${rows.length} rows)...');

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue; // Skip empty rows

          try {
            if (path.contains('Genres'))
              GenreDef.fromCsv(row);
            else if (path.contains('Attributes'))
              AttributeDef.fromCsv(row);
            else if (path.contains('Skills'))
              SkillDef.fromCsv(row);
            else if (path.contains('Species'))
              SpeciesDef.fromCsv(row);
            else if (path.contains('Traits'))
              TraitDef.fromCsv(row);
            else if (path.contains('Origins'))
              OriginDef.fromCsv(row);
            else if (path.contains('Feats'))
              FeatDef.fromCsv(row);
            else if (path.contains('Items')) ItemDef.fromCsv(row);
          } catch (e) {
            fail('Failed to parse row ${i + 2} in $path: $row\nError: $e');
          }
        }
      }
    });
  });
}
