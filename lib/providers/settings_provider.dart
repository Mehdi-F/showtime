import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../exceptions/app_exception.dart';

enum AppThemeMode { light, dark, auto }

class SettingsProvider extends ChangeNotifier {
  static const _themeModeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language';
  static const _enableNotificationsKey = 'settings_enable_notifications';

  AppThemeMode _themeMode = AppThemeMode.auto;
  String _language = 'fr'; // 'fr' or 'en'
  bool _enableNotifications = true;

  AppThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get enableNotifications => _enableNotifications;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = AppThemeMode.values[prefs.getInt(_themeModeKey) ?? 2]; // default to auto
    _language = prefs.getString(_languageKey) ?? 'fr';
    _enableNotifications = prefs.getBool(_enableNotificationsKey) ?? true;
    notifyListeners();
  }

  // These all notify *before* awaiting SharedPreferences on purpose: the
  // in-memory value is already correct at that point, and persistence is
  // slow enough on device that notifying afterwards made the UI look
  // frozen — the selection only appeared after leaving and re-entering
  // Settings. Persisting stays awaited so callers can still await the write.
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setLanguage(String lang) async {
    if (!AppConstants.supportedLanguages.contains(lang)) {
      throw ArgumentError('Unsupported language: $lang. Supported: ${AppConstants.supportedLanguages.join(", ")}');
    }
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
  }

  Future<void> setEnableNotifications(bool enabled) async {
    _enableNotifications = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableNotificationsKey, enabled);
  }

  Future<void> clearCache() async {
    // Placeholder for cache clearing logic (TMDB cache, etc.)
    final prefs = await SharedPreferences.getInstance();
    // This would also trigger a cache clear in TmdbService if needed
  }
}
