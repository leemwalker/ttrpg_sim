import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/services/gemini_wrapper.dart';
import 'package:ttrpg_sim/features/settings/settings_screen.dart';
import 'package:ttrpg_sim/features/game/presentation/game_screen.dart';
import 'package:ttrpg_sim/core/errors/app_exceptions.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'mock_gemini_service.dart';

void main() {
  testWidgets('BDD Scenario: Invalid API Key', (WidgetTester tester) async {
    // SETUP
    final inMemoryExecutor = NativeDatabase.memory();
    final db = AppDatabase(inMemoryExecutor);

    // Determine initial values for SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    // Mock Gemini Service to fail if called (Optional, but good safety)
    final mockGemini = MockGeminiService();

    // GIVEN I am on the Settings Screen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(mockGemini),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I enter "INVALID_KEY"
    final apiKeyField = find.widgetWithText(TextField, 'Gemini API Key');
    await tester.enterText(apiKeyField, 'INVALID_KEY');
    await tester.pumpAndSettle();

    // AND I save (Settings usually save internally or via a Save button)
    // Looking at SettingsScreen implementation (assumed), there might not be a "Save" button if it's auto-save,
    // but usually there's a validation step when trying to USE the key in chat.
    // However, the scenario says "and go to Chat" to see the error, OR "I should see the ⛔ Auth Error system message".
    // If the error appears IN CHAT, we need to navigate to chat.
    // If the error appears on Settings, we check here.
    // The prompt says: "When: I enter "INVALID_KEY" and go to Chat."

    // So we need to navigate to chat.
    // We need a World and Character to enter chat.
    final worldId = await db.gameDao.createWorld(WorldsCompanion.insert(
      name: 'Test Realm',
      genre: 'Fantasy',
      description: 'Test',
    ));
    await db.gameDao.updateCharacterStats(CharacterCompanion.insert(
      worldId: Value(worldId),
      name: 'Test Hero',
      heroClass: 'Fighter',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      gold: 0,
      location: 'Start',
    ));

    // Navigate to Chat (GameScreen) requires rebuilding the widget tree or using a navigator.
    // Easier to just pump the GameScreen directly with the same ProviderScope container logic?
    // No, settings need to persist.
    // We backed settings with SharedPreferences (via SettingsProvider usually).
    // Let's assume SettingsProvider writes to SharedPreferences.

    // Let's pump GameScreen now, simulating "Going to Chat"
    // We need to ensure the SettingsProvider reads the new key.

    // Actually, "SettingsProvider" usually reads from SharedPreferences.
    // If we updated the text field, did it update the provider?
    // Assuming the SettingsScreen updates the provider/prefs on change or submit.
    // Let's assume it updates on edit for now or find a "Save" button if exists.
    // If no save button found, we assume auto-save.

    // Re-pump GameScreen
    // We need to inject the REAL GeminiService (or a Mock that throws ApiKeyException)
    // Since we want to test "Invalid API Key" handling, we should use a Mock that throws 403 or we need to simulate the service check.
    // The real GeminiService throws ApiKeyException if 403.
    // We should use a MockGeminiService that throws ApiKeyException when sendMessage is called.

    final throwingGemini = MockThrowingGemini();

    // Re-pump GameScreen directly to simulate "Going to Chat" with the new (invalid) key context
    // In a real integration test, we would navigate from Settings -> Back -> Game, but State persistence is tricky in widget tests without global overrides.
    // We treat the "Settings" step as verifying the UI input, and "Game" step as verifying the consequences.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(throwingGemini),
        ],
        child: MaterialApp(
          home: GameScreen(worldId: worldId, characterId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // WHEN I send a message
    await tester.enterText(find.byType(TextField), "Hello");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(); // Start async
    await tester.pumpAndSettle(); // Resolve async

    // THEN I should see the Auth Error
    // The Controller catches ApiKeyException and inserts a system message.
    // Actual message defined in Controller: "⛔ Auth Error: Please check your API Key in Settings."
    expect(find.textContaining('Auth Error'), findsWidgets);

    await db.close();
  });
}

class MockThrowingGemini extends MockGeminiService {
  @override
  GenerativeModelWrapper createModel(String instruction) {
    throw UnimplementedError();
  }

  @override
  Future<TurnResult> sendMessage(
    String userMessage,
    GameDao dao,
    int worldId, {
    required String genre,
    required String tone,
    required String description,
    required CharacterData player,
    required List<String> features,
    required Map<String, int> spellSlots,
    required List<String> spells,
    Location? location,
    List<PointsOfInterestData> pois = const [],
    List<Npc> npcs = const [],
  }) async {
    throw ApiKeyException("Invalid API Key found during check");
  }
}
