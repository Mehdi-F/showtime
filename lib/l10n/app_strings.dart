class AppStrings {
  static const Map<String, Map<String, String>> _translations = {
    'fr': {
      // Navigation
      'nav.profile': 'Profil',
      'nav.series': 'Séries',
      'nav.films': 'Films',
      'nav.explore': 'Explorer',

      // Common
      'common.ok': 'OK',
      'common.cancel': 'Annuler',
      'common.save': 'Enregistrer',
      'common.delete': 'Supprimer',
      'common.reset': 'Réinitialiser',
      'common.apply': 'Appliquer',
      'common.filters': 'FILTRES',
      'common.sortBy': 'Trier par',

      // Sort options
      'sort.lastActivity': 'Dernier visionnage',
      'sort.lastAdded': 'Dernier ajout',
      'sort.alphabetical': 'Ordre alphabétique',

      // Filter options
      'filter.all': 'Tous',
      'filter.watching': 'En cours',
      'filter.completed': 'Vu',
      'filter.notStarted': 'Pas commencé',

      // Series
      'series.toWatch': 'À VOIR',
      'series.upcoming': 'À VENIR',
      'series.watchHistory': 'HISTORIQUE DE VISIONNAGE',
      'series.notWatching': 'PAS REGARDÉ DEPUIS UN MOMENT',
      'series.allCaughtUp': 'All caught up.',
      'series.trackShow': 'Track a show from Explorer to see it here.',

      // Films
      'films.toWatch': 'À VOIR',
      'films.nothingToWatch': 'Aucun titre ne correspond à ce filtre.',

      // Profile
      'profile.stats': 'STATISTIQUES',
      'profile.lists': 'MES LISTES',
      'profile.createList': 'CRÉER UNE LISTE',
      'profile.import': 'Importer depuis TV Time',
      'profile.signOut': 'Se déconnecter',
      'profile.user': 'Utilisateur',

      // Settings
      'settings.title': 'Paramètres',
      'settings.appearance': 'Apparence',
      'settings.general': 'Général',
      'settings.data': 'Données',
      'settings.account': 'Compte',
      'settings.theme': 'Thème',
      'settings.themeLight': 'Clair',
      'settings.themeDark': 'Sombre',
      'settings.themeAuto': 'Auto',
      'settings.language': 'Langue',
      'settings.notifications': 'Notifications',
      'settings.notificationsDesc': 'Notifications pour les nouveaux épisodes',
      'settings.clearCache': 'Vider le cache',
      'settings.clearCacheDesc': 'Supprime les données TMDB en cache',
      'settings.logout': 'Déconnexion',
      'settings.logoutConfirm': 'Déconnexion ?',
      'settings.logoutDesc': 'Vous allez être déconnecté de votre compte.',
      'settings.clearCacheConfirm': 'Vider le cache ?',
      'settings.clearCacheConfirmDesc':
          'Cela supprimera les données TMDB en cache. Vous pourrez les récharger.',
      'settings.cacheClear': 'Cache vidé',

      // Explorer
      'explorer.trending': 'Tendances',
      'explorer.popular': 'Populaire',
      'explorer.topRated': 'Meilleur classement',

      // Empty states
      'empty.noResults': 'Aucun résultat trouvé',
      'empty.tryAgain': 'Réessayer',
    },
    'en': {
      // Navigation
      'nav.profile': 'Profile',
      'nav.series': 'Series',
      'nav.films': 'Films',
      'nav.explore': 'Explore',

      // Common
      'common.ok': 'OK',
      'common.cancel': 'Cancel',
      'common.save': 'Save',
      'common.delete': 'Delete',
      'common.reset': 'Reset',
      'common.apply': 'Apply',
      'common.filters': 'FILTERS',
      'common.sortBy': 'Sort by',

      // Sort options
      'sort.lastActivity': 'Last watched',
      'sort.lastAdded': 'Last added',
      'sort.alphabetical': 'Alphabetical',

      // Filter options
      'filter.all': 'All',
      'filter.watching': 'Watching',
      'filter.completed': 'Watched',
      'filter.notStarted': 'Not started',

      // Series
      'series.toWatch': 'TO WATCH',
      'series.upcoming': 'UPCOMING',
      'series.watchHistory': 'WATCH HISTORY',
      'series.notWatching': 'HAVEN\'T WATCHED IN A WHILE',
      'series.allCaughtUp': 'All caught up.',
      'series.trackShow': 'Track a show from Explorer to see it here.',

      // Films
      'films.toWatch': 'TO WATCH',
      'films.nothingToWatch': 'No titles match this filter.',

      // Profile
      'profile.stats': 'STATISTICS',
      'profile.lists': 'MY LISTS',
      'profile.createList': 'CREATE A LIST',
      'profile.import': 'Import from TV Time',
      'profile.signOut': 'Sign out',
      'profile.user': 'User',

      // Settings
      'settings.title': 'Settings',
      'settings.appearance': 'Appearance',
      'settings.general': 'General',
      'settings.data': 'Data',
      'settings.account': 'Account',
      'settings.theme': 'Theme',
      'settings.themeLight': 'Light',
      'settings.themeDark': 'Dark',
      'settings.themeAuto': 'Auto',
      'settings.language': 'Language',
      'settings.notifications': 'Notifications',
      'settings.notificationsDesc': 'Notifications for new episodes',
      'settings.clearCache': 'Clear cache',
      'settings.clearCacheDesc': 'Removes cached TMDB data',
      'settings.logout': 'Sign out',
      'settings.logoutConfirm': 'Sign out?',
      'settings.logoutDesc': 'You will be signed out of your account.',
      'settings.clearCacheConfirm': 'Clear cache?',
      'settings.clearCacheConfirmDesc':
          'This will remove cached TMDB data. You can reload it later.',
      'settings.cacheClear': 'Cache cleared',

      // Explorer
      'explorer.trending': 'Trending',
      'explorer.popular': 'Popular',
      'explorer.topRated': 'Top Rated',

      // Empty states
      'empty.noResults': 'No results found',
      'empty.tryAgain': 'Try again',
    },
  };

  static String get(String key, {String language = 'fr'}) {
    return _translations[language]?[key] ?? key;
  }

  static String getOrDefault(String key, String defaultValue, {String language = 'fr'}) {
    return _translations[language]?[key] ?? defaultValue;
  }
}

extension StringLocalization on String {
  String tr({String language = 'fr'}) => AppStrings.get(this, language: language);
}
