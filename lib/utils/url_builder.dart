import '../config/tmdb_config.dart';

/// Centralized URL builder for TMDB images and API endpoints.
/// Eliminates string concatenation scattered throughout the codebase,
/// making image sizing and endpoint changes a single point of edit.
class UrlBuilder {
  // Poster images (movie/TV show posters)
  static String posterTiny(String? posterPath) =>
      posterPath != null ? '${TmdbConfig.imageBaseUrlTiny}$posterPath' : '';

  static String posterSmall(String? posterPath) =>
      posterPath != null ? '${TmdbConfig.imageBaseUrlSmall}$posterPath' : '';

  static String posterMedium(String? posterPath) =>
      posterPath != null ? '${TmdbConfig.imageBaseUrlMedium}$posterPath' : '';

  static String posterLarge(String? posterPath) =>
      posterPath != null ? '${TmdbConfig.imageBaseUrlLarge}$posterPath' : '';

  static String posterOriginal(String? posterPath) =>
      posterPath != null ? '${TmdbConfig.imageBaseUrlOriginal}$posterPath' : '';

  // Backdrop images (large background images)
  static String backdropSmall(String? backdropPath) =>
      backdropPath != null ? '${TmdbConfig.imageBaseUrlSmall}$backdropPath' : '';

  static String backdropMedium(String? backdropPath) =>
      backdropPath != null ? '${TmdbConfig.imageBaseUrlMedium}$backdropPath' : '';

  static String backdropLarge(String? backdropPath) =>
      backdropPath != null ? '${TmdbConfig.imageBaseUrlLarge}$backdropPath' : '';

  static String backdropOriginal(String? backdropPath) =>
      backdropPath != null ? '${TmdbConfig.imageBaseUrlOriginal}$backdropPath' : '';

  // Still images (episode stills)
  static String stillSmall(String? stillPath) =>
      stillPath != null ? '${TmdbConfig.imageBaseUrlSmall}$stillPath' : '';

  static String stillMedium(String? stillPath) =>
      stillPath != null ? '${TmdbConfig.imageBaseUrlMedium}$stillPath' : '';

  static String stillOriginal(String? stillPath) =>
      stillPath != null ? '${TmdbConfig.imageBaseUrlOriginal}$stillPath' : '';

  // Profile images (cast/crew photos)
  static String profileTiny(String? profilePath) =>
      profilePath != null ? '${TmdbConfig.imageBaseUrlTiny}$profilePath' : '';

  static String profileSmall(String? profilePath) =>
      profilePath != null ? '${TmdbConfig.imageBaseUrlSmall}$profilePath' : '';

  static String profileOriginal(String? profilePath) =>
      profilePath != null ? '${TmdbConfig.imageBaseUrlOriginal}$profilePath' : '';

  // Logo images (provider logos, etc.)
  static String logoTiny(String? logoPath) =>
      logoPath != null ? '${TmdbConfig.imageBaseUrlTiny}$logoPath' : '';

  static String logoSmall(String? logoPath) =>
      logoPath != null ? '${TmdbConfig.imageBaseUrlSmall}$logoPath' : '';

  static String logoOriginal(String? logoPath) =>
      logoPath != null ? '${TmdbConfig.imageBaseUrlOriginal}$logoPath' : '';

  // Generic image URL builder for custom sizing
  static String image(String imageSize, String? imagePath) =>
      imagePath != null ? 'https://image.tmdb.org/t/p/$imageSize$imagePath' : '';
}
