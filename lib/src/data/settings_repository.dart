import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_goal.dart';

/// Stores the daily goal and the Kassalapp API token.
///
/// The goal is ordinary preference data; the token is a credential and goes to
/// the platform keystore/keychain instead.
class SettingsRepository {
  SettingsRepository({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kcalKey = 'goal_kcal';
  static const _proteinKey = 'goal_protein_g';
  static const _carbsKey = 'goal_carbs_g';
  static const _fatKey = 'goal_fat_g';
  static const _onboardedKey = 'has_onboarded';
  static const _tokenKey = 'kassal_api_token';

  /// A token baked in at build time with
  /// `--dart-define=KASSAL_API_TOKEN=...`, used as the default so a developer
  /// build does not have to retype it. Stored settings still win.
  static const String _compileTimeToken = String.fromEnvironment(
    'KASSAL_API_TOKEN',
  );

  Future<DailyGoal> loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyGoal(
      kcal: prefs.getDouble(_kcalKey) ?? DailyGoal.fallback.kcal,
      proteinG: prefs.getDouble(_proteinKey),
      carbsG: prefs.getDouble(_carbsKey),
      fatG: prefs.getDouble(_fatKey),
    );
  }

  Future<void> saveGoal(DailyGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kcalKey, goal.kcal);
    await _setOrRemove(prefs, _proteinKey, goal.proteinG);
    await _setOrRemove(prefs, _carbsKey, goal.carbsG);
    await _setOrRemove(prefs, _fatKey, goal.fatG);
  }

  Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, value);
  }

  Future<String?> readToken() async {
    try {
      final stored = await _secure.read(key: _tokenKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } on Exception {
      // Secure storage is unavailable on some desktop setups (Linux without
      // libsecret, for one). Fall through to the compile-time token rather
      // than making the whole app unusable.
    }
    return _compileTimeToken.isEmpty ? null : _compileTimeToken;
  }

  Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token.trim());
  }

  Future<void> clearToken() async {
    await _secure.delete(key: _tokenKey);
  }

  static Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, value);
    }
  }
}
