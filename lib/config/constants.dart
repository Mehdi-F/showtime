class AppConstants {
  AppConstants._();

  // Durations
  static const staleSeriesDuration = Duration(days: 14);
  static const tmdbRequestTimeout = Duration(seconds: 12);
  static const tmdbCacheTtl = Duration(hours: 6);

  // Pagination
  static const filmsPageSize = 21;
  static const seriesPageSize = 20;
  static const profileInitialLoadTimeout = Duration(milliseconds: 600);
  static const profileMaxRecentHistory = 200;

  // UI
  static const filmsPosterAspectRatio = 0.67;
  static const scrollLoadThreshold = 400;
  static const maxCastMembers = 12;
  static const confettiDuration = Duration(seconds: 3);

  // Localization
  static const supportedLanguages = {'fr', 'en'};
  static const defaultLanguage = 'fr';
}
