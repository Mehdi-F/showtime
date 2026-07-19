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
      'common.edit': 'Modifier',
      'common.change': 'Changer',
      'common.done': 'Terminé',
      'common.retry': 'Réessayer',
      'common.loadMore': 'Charger plus',
      'common.chooseFile': 'Choisir le fichier zip',

      // Sort options
      'sort.lastActivity': 'Dernier visionnage',
      'sort.lastAdded': 'Dernier ajout',
      'sort.alphabetical': 'Ordre alphabétique',

      // Filter options
      'filter.all': 'Tous',
      'filter.watching': 'En cours',
      'filter.completed': 'Vu',
      'filter.notStarted': 'Pas commencé',

      // Group labels
      'group.inProgress': 'EN COURS',
      'group.notStarted': 'PAS COMMENCÉ',
      'group.upToDate': 'À JOUR',
      'group.completed': 'TERMINÉ',
      'group.cancelled': 'ARRÊTÉE',
      'group.watched': 'VU',
      'group.notWatched': 'PAS VU',

      // Series
      'series.toWatch': 'À VOIR',
      'series.upcoming': 'À VENIR',
      'series.watchHistory': 'HISTORIQUE DE VISIONNAGE',
      'series.notWatching': 'PAS REGARDÉ DEPUIS UN MOMENT',
      'series.allCaughtUp': 'Vous êtes à jour.',
      'series.trackShow': 'Ajoutez une série depuis Explorer pour la voir ici.',
      'series.upcomingEmpty': 'Aucun épisode prévu pour le moment.',

      // Films
      'films.toWatch': 'À VOIR',
      'films.nothingToWatch': 'Aucun titre ne correspond à ce filtre.',

      // Profile
      'profile.stats': 'STATISTIQUES',
      'profile.lists': 'MES LISTES',
      'profile.createList': 'CRÉER UNE LISTE',
      'profile.friends': 'Amis',
      'profile.import': 'Importer depuis TV Time',
      'profile.signOut': 'Se déconnecter',
      'profile.user': 'Utilisateur',
      'profile.seriesWatched': 'séries vues',
      'profile.filmsWatched': 'films vus',
      'profile.episodesWatched': 'épisodes vus',
      'profile.timeSpentSeries': 'Temps passé devant des séries',
      'profile.timeSpentFilms': 'Temps passé devant des films',
      'profile.editProfile': 'MODIFIER',
      'profile.series': 'Séries',
      'profile.seriesFavorite': 'Séries préférées',
      'profile.films': 'Films',
      'profile.filmsFavorite': 'Films préférés',

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
      'explorer.search': 'Rechercher un film, une série...',
      'explorer.noResults': 'Aucun résultat.',
      'explorer.browseAllSeries': 'PARCOURIR TOUTES LES SÉRIES',
      'explorer.browseAllMovies': 'PARCOURIR TOUS LES FILMS',
      'explorer.allSeries': 'Toutes les séries',
      'explorer.allMovies': 'Tous les films',
      'explorer.bestSeriesForYou': 'Meilleures séries pour vous',
      'explorer.seriesTrending': 'Séries tendance',
      'explorer.popularInYourCountry': 'Populaire dans votre pays',
      'explorer.moviesTrending': 'Films tendance',
      'explorer.popularMovies': 'Films populaires',
      'explorer.series': 'Séries',
      'explorer.movie': 'Film',
      'explorer.searchFailed': 'Search failed. Check your connection and try again.',

      // List operations
      'list.rename': 'Renommer la liste',
      'list.createNew': 'Nouvelle liste',
      'list.delete': 'Supprimer la liste ?',
      'list.deleteConfirm': 'sera définitivement supprimée.',
      'list.empty': 'Cette liste est vide.',
      'list.items': 'élément(s)',

      // Import/Export
      'import.title': 'Importer depuis TV Time',
      'import.selectFile': 'Sélectionner fichier',
      'import.importing': 'Importation en cours',
      'import.imported': 'série(s) importée(s).',
      'import.failed': 'échec(s) (réessaie plus tard).',

      // Time units
      'time.days': 'JOURS',
      'time.hours': 'HEURES',
      'time.months': 'MOIS',
      'time.day': 'JOUR',

      // Days
      'day.yesterday': 'HIER',
      'day.today': 'AUJOURD\'HUI',
      'day.tomorrow': 'DEMAIN',
      'day.unknown': 'DATE INCONNUE',

      // Badges
      'badge.new': 'NOUVEAU',
      'badge.premiere': 'PREMIERE',
      'badge.aired': 'DIFFUSÉ',
      'badge.mostRecent': 'PLUS RÉCENT',

      // Detail screens
      'detail.about': 'À propos',
      'detail.episodes': 'Épisodes',
      'detail.cast': 'Casting',
      'detail.similar': 'Similaire',
      'detail.couldNotLoad': 'Impossible de charger.',

      // Dialogs
      'dialog.editProfile': 'Modifier le profil',
      'dialog.editProfileName': 'Modifier le nom du profil',

      // Empty states
      'empty.noResults': 'Aucun résultat.',
      'empty.tryAgain': 'Réessayer',
      'empty.loadFailed': 'Impossible de charger.',
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
      'common.edit': 'Edit',
      'common.change': 'Change',
      'common.done': 'Done',
      'common.retry': 'Retry',
      'common.loadMore': 'Load more',
      'common.chooseFile': 'Choose zip file',

      // Sort options
      'sort.lastActivity': 'Last watched',
      'sort.lastAdded': 'Last added',
      'sort.alphabetical': 'Alphabetical',

      // Filter options
      'filter.all': 'All',
      'filter.watching': 'Watching',
      'filter.completed': 'Watched',
      'filter.notStarted': 'Not started',

      // Group labels
      'group.inProgress': 'WATCHING',
      'group.notStarted': 'NOT STARTED',
      'group.upToDate': 'UP TO DATE',
      'group.completed': 'COMPLETED',
      'group.cancelled': 'CANCELLED',
      'group.watched': 'WATCHED',
      'group.notWatched': 'NOT WATCHED',

      // Series
      'series.toWatch': 'TO WATCH',
      'series.upcoming': 'UPCOMING',
      'series.watchHistory': 'WATCH HISTORY',
      'series.notWatching': 'HAVEN\'T WATCHED IN A WHILE',
      'series.allCaughtUp': 'All caught up.',
      'series.trackShow': 'Track a show from Explorer to see it here.',
      'series.upcomingEmpty': 'No upcoming episodes scheduled.',

      // Films
      'films.toWatch': 'TO WATCH',
      'films.nothingToWatch': 'No titles match this filter.',

      // Profile
      'profile.stats': 'STATISTICS',
      'profile.lists': 'MY LISTS',
      'profile.createList': 'CREATE A LIST',
      'profile.friends': 'Friends',
      'profile.import': 'Import from TV Time',
      'profile.signOut': 'Sign out',
      'profile.user': 'User',
      'profile.seriesWatched': 'series watched',
      'profile.filmsWatched': 'films watched',
      'profile.episodesWatched': 'episodes watched',
      'profile.timeSpentSeries': 'Time spent on series',
      'profile.timeSpentFilms': 'Time spent on films',
      'profile.editProfile': 'EDIT',
      'profile.series': 'Series',
      'profile.seriesFavorite': 'Favorite series',
      'profile.films': 'Films',
      'profile.filmsFavorite': 'Favorite films',

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
      'explorer.search': 'Search for a movie or series...',
      'explorer.noResults': 'No results.',
      'explorer.browseAllSeries': 'BROWSE ALL SERIES',
      'explorer.browseAllMovies': 'BROWSE ALL MOVIES',
      'explorer.allSeries': 'All series',
      'explorer.allMovies': 'All movies',
      'explorer.bestSeriesForYou': 'Best series for you',
      'explorer.seriesTrending': 'Series trending',
      'explorer.popularInYourCountry': 'Popular in your country',
      'explorer.moviesTrending': 'Movies trending',
      'explorer.popularMovies': 'Popular movies',
      'explorer.series': 'Series',
      'explorer.movie': 'Movie',
      'explorer.searchFailed': 'Search failed. Check your connection and try again.',

      // List operations
      'list.rename': 'Rename list',
      'list.createNew': 'New list',
      'list.delete': 'Delete list?',
      'list.deleteConfirm': 'will be permanently deleted.',
      'list.empty': 'This list is empty.',
      'list.items': 'item(s)',

      // Import/Export
      'import.title': 'Import from TV Time',
      'import.selectFile': 'Select file',
      'import.importing': 'Importing',
      'import.imported': 'series imported.',
      'import.failed': 'failure(s) (will retry later).',

      // Time units
      'time.days': 'DAYS',
      'time.hours': 'HOURS',
      'time.months': 'MONTHS',
      'time.day': 'DAY',

      // Days
      'day.yesterday': 'YESTERDAY',
      'day.today': 'TODAY',
      'day.tomorrow': 'TOMORROW',
      'day.unknown': 'UNKNOWN DATE',

      // Badges
      'badge.new': 'NEW',
      'badge.premiere': 'PREMIERE',
      'badge.aired': 'AIRED',
      'badge.mostRecent': 'MOST RECENT',

      // Detail screens
      'detail.about': 'About',
      'detail.episodes': 'Episodes',
      'detail.cast': 'Cast',
      'detail.similar': 'Similar',
      'detail.couldNotLoad': 'Could not load.',

      // Dialogs
      'dialog.editProfile': 'Edit profile',
      'dialog.editProfileName': 'Edit profile name',

      // Empty states
      'empty.noResults': 'No results.',
      'empty.tryAgain': 'Try again',
      'empty.loadFailed': 'Could not load.',
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
