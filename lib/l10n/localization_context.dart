import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_strings.dart';

extension LocalizationContext on BuildContext {
  /// Get the current language from SettingsProvider
  String get currentLanguage {
    final settings = read<SettingsProvider>();
    return settings.language;
  }

  /// Translate a key using the current language setting
  String tr(String key) {
    return AppStrings.get(key, language: currentLanguage);
  }

  /// Watch language changes and rebuild
  String watchTr(String key) {
    final settings = watch<SettingsProvider>();
    return AppStrings.get(key, language: settings.language);
  }
}
