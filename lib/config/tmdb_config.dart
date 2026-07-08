class TmdbConfig {
  static const apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const baseUrl = 'https://api.themoviedb.org/3';

  // TMDB serves images pre-resized behind distinct CDN paths — requesting
  // the smallest size that still looks sharp for where it's shown (rather
  // than always pulling the same wide image everywhere) matters a lot on a
  // slow connection: a 56x78 list thumbnail doesn't need a 500px image.
  static const imageBaseUrlTiny = 'https://image.tmdb.org/t/p/w154'; // small thumbnails, list rows, cast photos
  static const imageBaseUrlSmall = 'https://image.tmdb.org/t/p/w300'; // gallery thumbnails, episode stills
  static const imageBaseUrlMedium = 'https://image.tmdb.org/t/p/w342'; // grid poster tiles
  static const imageBaseUrlLarge = 'https://image.tmdb.org/t/p/w780'; // banners, backdrops
  static const imageBaseUrlOriginal = 'https://image.tmdb.org/t/p/original'; // full-screen viewer

  static const attribution =
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';
}
