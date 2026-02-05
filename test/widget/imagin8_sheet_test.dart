import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/character/presentation/imagin8_sheet.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  testWidgets('Imagin8Sheet shows Export Campaign button and triggers logic',
      (WidgetTester tester) async {
    // 1. Setup DB and Data
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    // Seed Character and World
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test World',
      genre: 'Fantasy',
      description: 'Desc',
      system: const drift.Value('imagin8'),
    ));

    final charId =
        await db.gameDao.updateCharacterStats(CharacterCompanion.insert(
      name: 'Test Char',
      worldId: drift.Value(worldId),
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: 'Loc',
      species: const drift.Value('Human'),
      origin: const drift.Value('Earth'),
    ));

    final character = await db.gameDao.getCharacter(worldId);

    // 2. Pump Widget
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        Scaffold(body: Imagin8Sheet(character: character!)),
                  ));
                },
                child: const Text('Open Sheet'),
              ),
            ),
          );
        }),
      ),
    ));

    // Open the sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 3. Verify Button Exists
    final exportBtn = find.text('Export Campaign');
    expect(exportBtn, findsOneWidget);

    // 4. Verify Tap triggers Snackbar
    await tester.tap(exportBtn);
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Wait for snackbar

    expect(find.text('Preparing backup...'), findsOneWidget);

    // Note: The actual export might fail or throw because BackupService tries to use `path_provider`
    // or `Share.shareXFiles` which might not work in widget test environment without mocking platform channels.
    // However, seeing "Preparing backup..." proves the button is hooked up.
  });
}
