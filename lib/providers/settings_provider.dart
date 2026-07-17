import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeMode { light, dark, auto }

class SettingsProvider extends ChangeNotifier {
  static const _themeModeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language';
  static const _enableNotificationsKey = 'settings_enable_notifications';

  ThemeMode _themeMode = ThemeMode.auto;
  String _language = 'fr'; // 'fr' or 'en'
  bool _enableNotifications = true;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get enableNotifications => _enableNotifications;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt(_themeModeKey) ?? 2]; // default to auto
    _language = prefs.getString(_languageKey) ?? 'fr';
    _enableNotifications = prefs.getBool(_enableNotificationsKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool enabled) async {
    _enableNotifications = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableNotificationsKey, enabled);
    notifyListeners();
  }

  Future<void> clearCache() async {
    // Placeholder for cache clearing logic (TMDB cache, etc.)
    final prefs = await SharedPreferences.getInstance();
    // This would also trigger a cache clear in TmdbService if needed
  }
}
