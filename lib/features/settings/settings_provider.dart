import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/features/settings/settings_service.dart';

class SettingsState {
  final ThemeMode theme;
  final String? apiKey;
  final String modelName;

  const SettingsState({
    this.theme = ThemeMode.system,
    this.apiKey,
    this.modelName = 'gemini-1.5-flash',
  });

  SettingsState copyWith({
    ThemeMode? theme,
    String? apiKey,
    String? modelName,
  }) {
    return SettingsState(
      theme: theme ?? this.theme,
      apiKey: apiKey ??
          this.apiKey, // Note: To clear, we might need a specific flag or nullable logic, but for now simple replacement
      modelName: modelName ?? this.modelName,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final theme = await _service.getThemeMode();
    final apiKey = await _service.getApiKey();
    final model = await _service.getModel();
    state = SettingsState(
      theme: theme,
      apiKey: apiKey,
      modelName: model,
    );
  }

  Future<void> setTheme(ThemeMode theme) async {
    await _service.setThemeMode(theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> setApiKey(String key) async {
    await _service.setApiKey(key);
    // If empty string passed, it's cleared in service.
    // In state, we set it to null if empty for cleaner logic downstream, or keep as string.
    // Service returns String? so let's match that.
    state = SettingsState(
      theme: state.theme,
      apiKey: key.isEmpty ? null : key,
      modelName: state.modelName,
    );
  }

  Future<void> setModel(String modelName) async {
    await _service.setModel(modelName);
    state = state.copyWith(modelName: modelName);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(SettingsService());
});
