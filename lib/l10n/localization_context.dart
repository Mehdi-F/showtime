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

  /// Get array of weekday names (Monday-Sunday) in current language
  List<String> getWeekdays() {
    final keys = [
      'weekday.monday',
      'weekday.tuesday',
      'weekday.wednesday',
      'weekday.thursday',
      'weekday.friday',
      'weekday.saturday',
      'weekday.sunday',
    ];
    return keys.map(tr).toList();
  }

  /// Get array of abbreviated month names (Jan-Dec) in current language
  List<String> getMonths() {
    final keys = [
      'month.january',
      'month.february',
      'month.march',
      'month.april',
      'month.may',
      'month.june',
      'month.july',
      'month.august',
      'month.september',
      'month.october',
      'month.november',
      'month.december',
    ];
    return keys.map(tr).toList();
  }
}
