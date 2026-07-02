class TmdbConfig {
  static const apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const baseUrl = 'https://api.themoviedb.org/3';
  static const imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static const attribution =
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';
}
