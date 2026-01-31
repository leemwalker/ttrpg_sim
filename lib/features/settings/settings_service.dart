import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ttrpg_sim/features/settings/paid_key_usage_mode.dart';

class SettingsService {
  static const _kTheme = 'theme';
  static const _kApiKey = 'api_key';
  static const _kPaidApiKey = 'paid_api_key';
  static const _kModel = 'model';
  static const _kPaidKeyMode = 'paid_key_mode';
  static const _kPaidKeyRate = 'paid_key_rate';
  static const _kGhostwritingModel = 'ghostwriting_model';

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

  Future<String?> getPaidApiKey() async {
    try {
      return await _secureStorage.read(key: _kPaidApiKey);
    } catch (e) {
      debugPrint('Error reading paid API key: $e');
      return null;
    }
  }

  Future<void> setPaidApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: _kPaidApiKey);
    } else {
      await _secureStorage.write(key: _kPaidApiKey, value: apiKey);
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

  Future<PaidKeyUsageMode> getPaidKeyMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kPaidKeyMode);
    if (index == null || index >= PaidKeyUsageMode.values.length) {
      return PaidKeyUsageMode.fallback;
    }
    return PaidKeyUsageMode.values[index];
  }

  Future<void> setPaidKeyMode(PaidKeyUsageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPaidKeyMode, mode.index);
  }

  Future<double> getPaidKeyRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kPaidKeyRate) ?? 1.0;
  }

  Future<void> setPaidKeyRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPaidKeyRate, rate.clamp(0.1, 10.0));
  }

  Future<String> getGhostwritingModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGhostwritingModel) ?? 'models/gemini-2.5-flash';
  }

  Future<void> setGhostwritingModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGhostwritingModel, model);
  }
}
