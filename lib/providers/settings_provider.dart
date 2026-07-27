import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tmdb_config.dart';

enum AppThemeMode { light, dark, auto }

class SettingsProvider extends ChangeNotifier {
  static const _themeModeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language';
  static const _enableNotificationsKey = 'settings_enable_notifications';
  static const _watchRegionKey = 'settings_watch_region';

  AppThemeMode _themeMode = AppThemeMode.auto;
  String _language = 'fr'; // 'fr' or 'en'
  bool _enableNotifications = true;
  String _watchRegion = TmdbConfig.defaultRegion;

  AppThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get enableNotifications => _enableNotifications;
  String get watchRegion => _watchRegion;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = AppThemeMode.values[prefs.getInt(_themeModeKey) ?? 2]; // default to auto
    _language = prefs.getString(_languageKey) ?? 'fr';
    _enableNotifications = prefs.getBool(_enableNotificationsKey) ?? true;
    _watchRegion = prefs.getString(_watchRegionKey) ?? TmdbConfig.defaultRegion;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
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

  Future<void> setWatchRegion(String region) async {
    _watchRegion = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchRegionKey, region);
    notifyListeners();
  }

  Future<void> clearCache() async {
    // Placeholder for cache clearing logic (TMDB cache, etc.)
    final prefs = await SharedPreferences.getInstance();
    // This would also trigger a cache clear in TmdbService if needed
  }
}
