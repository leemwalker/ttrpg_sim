import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle, AssetBundle;
import 'package:ttrpg_sim/core/database/database.dart';

class Imagin8Seed {
  static Future<void> seed(AppDatabase db, {AssetBundle? bundle}) async {
    final existingCount =
        await db.select(db.imagin8Cards).get().then((l) => l.length);
    if (existingCount == 0) {
      print('🌱 Seeding Imagin8 Cards from CSV...');

      try {
        final b = bundle ?? rootBundle;
        final csvString = await b.loadString('assets/imagin8/core_decks.csv');
        // Parse CSV, skipping the first row (header) implicitly if we iterate from index 1,
        // or specifically checking. Let's just convert and skip index 0.
        final List<List<dynamic>> rows =
            const CsvToListConverter().convert(csvString, eol: '\n');

        if (rows.isEmpty) return;

        // Skip header row
        final dataRows = rows.skip(1);

        await db.batch((batch) {
          final companions = dataRows
              .map((row) {
                // Columns: Deck, Type, Name, Description, Mechanic
                // Safety check for row length
                if (row.length < 5) return null;

                final deck = row[0].toString();
                final type = row[1].toString();
                final name = row[2].toString();
                final description = row[3].toString();
                final mechanic = row[4].toString();

                return Imagin8CardsCompanion(
                  deck: Value(deck),
                  type: Value(type),
                  name: Value(name),
                  description: Value(description),
                  mechanic: Value(mechanic),
                );
              })
              .whereType<Imagin8CardsCompanion>()
              .toList(); // Filter out nulls

          batch.insertAll(db.imagin8Cards, companions);
        });
        print('✅ Seeded ${dataRows.length} cards.');
      } catch (e) {
        print('❌ Error seeding Imagin8 cards: $e');
      }
    }
  }
}
