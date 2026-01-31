import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttrpg_sim/features/settings/settings_screen.dart';
import 'package:ttrpg_sim/features/settings/paid_key_usage_mode.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:drift/native.dart';
import '../bdd/mock_gemini_service.dart';

void main() {
  group('Paid API Key Settings', () {
    testWidgets('Scenario: Configure Paid API Key', (tester) async {
      // GIVEN I am on the Settings Screen
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      final mockGemini = MockGeminiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            geminiServiceProvider.overrideWithValue(mockGemini),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // THEN I should see the Paid API Key section
      expect(find.text('Paid API Key'), findsOneWidget);

      // AND I should see the three mode options
      expect(find.text('Fallback'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Rate-Based'), findsOneWidget);

      await db.close();
    });

    testWidgets('Scenario: Default mode is Fallback (no slider)',
        (tester) async {
      // GIVEN I am on the Settings Screen with default settings
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      final mockGemini = MockGeminiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            geminiServiceProvider.overrideWithValue(mockGemini),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to ensure we can see the full section
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // THEN I should NOT see the rate slider (default is Fallback)
      expect(find.byType(Slider), findsNothing);

      await db.close();
    });
  });

  group('Ghostwriting Model Selection', () {
    testWidgets('Scenario: Ghostwriting section exists', (tester) async {
      // GIVEN I am on the Settings Screen
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      final mockGemini = MockGeminiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            geminiServiceProvider.overrideWithValue(mockGemini),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to find the ghostwriting section
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // THEN I should see the ghostwriting section header
      expect(find.text('Ghostwriting (LitRPG Studio)'), findsOneWidget);

      await db.close();
    });
  });
}
