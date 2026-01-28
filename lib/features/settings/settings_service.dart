import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const _kTheme = 'theme';
  static const _kApiKey = 'api_key';
  static const _kModel = 'model';

  // Secure storage for sensitive data
  final _secureStorage = const FlutterSecureStorage();

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kTheme);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTheme, mode.index);
  }

  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: _kApiKey);
    } catch (e) {
      // Fallback or handle error (e.g. if key is corrupted)
      // For now, return null so user is prompted again
      debugPrint('Error reading API key: $e');
      return null;
    }
  }

  Future<void> setApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: _kApiKey);
    } else {
      await _secureStorage.write(key: _kApiKey, value: apiKey);
    }
  }

  Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kModel) ?? 'models/gemini-2.5-flash';
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, model);
  }
}
