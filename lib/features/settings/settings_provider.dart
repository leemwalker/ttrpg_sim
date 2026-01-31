import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/features/settings/settings_service.dart';
import 'package:ttrpg_sim/features/settings/paid_key_usage_mode.dart';

class SettingsState {
  final ThemeMode theme;
  final String? apiKey;
  final String modelName;
  final String? paidApiKey;
  final PaidKeyUsageMode paidKeyMode;
  final double paidKeyRate; // 0.1 to 10.0 times per minute
  final String ghostwritingModel;

  const SettingsState({
    this.theme = ThemeMode.system,
    this.apiKey,
    this.modelName = 'models/gemini-2.5-flash',
    this.paidApiKey,
    this.paidKeyMode = PaidKeyUsageMode.fallback,
    this.paidKeyRate = 1.0,
    this.ghostwritingModel = 'models/gemini-2.5-flash',
  });

  SettingsState copyWith({
    ThemeMode? theme,
    String? apiKey,
    String? modelName,
    String? paidApiKey,
    PaidKeyUsageMode? paidKeyMode,
    double? paidKeyRate,
    String? ghostwritingModel,
  }) {
    return SettingsState(
      theme: theme ?? this.theme,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      paidApiKey: paidApiKey ?? this.paidApiKey,
      paidKeyMode: paidKeyMode ?? this.paidKeyMode,
      paidKeyRate: paidKeyRate ?? this.paidKeyRate,
      ghostwritingModel: ghostwritingModel ?? this.ghostwritingModel,
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
    final paidApiKey = await _service.getPaidApiKey();
    final paidKeyMode = await _service.getPaidKeyMode();
    final paidKeyRate = await _service.getPaidKeyRate();
    final ghostwritingModel = await _service.getGhostwritingModel();

    state = SettingsState(
      theme: theme,
      apiKey: apiKey,
      modelName: model,
      paidApiKey: paidApiKey,
      paidKeyMode: paidKeyMode,
      paidKeyRate: paidKeyRate,
      ghostwritingModel: ghostwritingModel,
    );
  }

  Future<void> setTheme(ThemeMode theme) async {
    await _service.setThemeMode(theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> setApiKey(String key) async {
    await _service.setApiKey(key);
    state = SettingsState(
      theme: state.theme,
      apiKey: key.isEmpty ? null : key,
      modelName: state.modelName,
      paidApiKey: state.paidApiKey,
      paidKeyMode: state.paidKeyMode,
      paidKeyRate: state.paidKeyRate,
      ghostwritingModel: state.ghostwritingModel,
    );
  }

  Future<void> setModel(String modelName) async {
    await _service.setModel(modelName);
    state = state.copyWith(modelName: modelName);
  }

  Future<void> setPaidApiKey(String key) async {
    await _service.setPaidApiKey(key);
    state = SettingsState(
      theme: state.theme,
      apiKey: state.apiKey,
      modelName: state.modelName,
      paidApiKey: key.isEmpty ? null : key,
      paidKeyMode: state.paidKeyMode,
      paidKeyRate: state.paidKeyRate,
      ghostwritingModel: state.ghostwritingModel,
    );
  }

  Future<void> setPaidKeyMode(PaidKeyUsageMode mode) async {
    await _service.setPaidKeyMode(mode);
    state = state.copyWith(paidKeyMode: mode);
  }

  Future<void> setPaidKeyRate(double rate) async {
    await _service.setPaidKeyRate(rate);
    state = state.copyWith(paidKeyRate: rate);
  }

  Future<void> setGhostwritingModel(String model) async {
    await _service.setGhostwritingModel(model);
    state = state.copyWith(ghostwritingModel: model);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(SettingsService());
});
