class TmdbSearchResult {
  final int id;
  final String mediaType; // "tv" | "movie"
  final String title;
  final String? posterPath;
  final String? year;

  TmdbSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.year,
  });

  factory TmdbSearchResult.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String;
    final title = mediaType == 'tv' ? json['name'] as String : json['title'] as String;
    final dateField = mediaType == 'tv' ? json['first_air_date'] : json['release_date'];
    final date = dateField as String?;

    return TmdbSearchResult(
      id: json['id'] as int,
      mediaType: mediaType,
      title: title,
      posterPath: json['poster_path'] as String?,
      year: (date != null && date.length >= 4) ? date.substring(0, 4) : null,
    );
  }
}

class SeasonSummary {
  final int seasonNumber;
  final int episodeCount;
  final String name;

  SeasonSummary({required this.seasonNumber, required this.episodeCount, required this.name});

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
        seasonNumber: json['season_number'] as int,
        episodeCount: json['episode_count'] as int,
        name: json['name'] as String,
      );
}

class NextEpisode {
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final DateTime? airDate;

  NextEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    required this.airDate,
  });

  String get key => 's${seasonNumber}e$episodeNumber';

  factory NextEpisode.fromJson(Map<String, dynamic> json) {
    DateTime? airDate;
    if (json['air_date'] != null) {
      try {
        airDate = DateTime.parse(json['air_date'] as String);
      } catch (_) {
        airDate = null;
      }
    }
    return NextEpisode(
      seasonNumber: json['season_number'] as int,
      episodeNumber: json['episode_number'] as int,
      name: json['name'] as String,
      airDate: airDate,
    );
  }
}

class TvDetails {
  final int id;
  final String name;
  final String? posterPath;
  final String? backdropPath;
  final List<SeasonSummary> seasons;
  final NextEpisode? nextEpisodeToAir;
  final String status; // TMDB raw value: "Returning Series" | "Ended" | "Canceled" | "In Production" | "Planned" | "Pilot"
  final int episodeRunTime; // average episode duration in minutes
  final List<String> genres;
  final String overview;
  final double voteAverage;
  final int? firstAirYear;
  final int? lastAirYear;
  final int specialsEpisodeCount; // 0 if the show has no season 0

  TvDetails({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.backdropPath,
    required this.seasons,
    required this.nextEpisodeToAir,
    required this.status,
    required this.episodeRunTime,
    required this.genres,
    required this.overview,
    required this.voteAverage,
    required this.firstAirYear,
    required this.lastAirYear,
    required this.specialsEpisodeCount,
  });

  bool get isEnded => status == 'Ended' || status == 'Canceled';
  bool get hasSpecials => specialsEpisodeCount > 0;

  factory TvDetails.fromJson(Map<String, dynamic> json) {
    final runTimes = (json['episode_run_time'] as List<dynamic>? ?? []).cast<int>();
    final rawSeasons = (json['seasons'] as List<dynamic>? ?? [])
        .map((s) => SeasonSummary.fromJson(s as Map<String, dynamic>))
        .toList();
    final specials = rawSeasons.where((s) => s.seasonNumber == 0).toList();
    final firstAirDate = json['first_air_date'] as String?;
    final lastAirDate = json['last_air_date'] as String?;
    return TvDetails(
      id: json['id'] as int,
      name: json['name'] as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      seasons: rawSeasons.where((s) => s.seasonNumber > 0).toList(),
      nextEpisodeToAir: json['next_episode_to_air'] != null
          ? NextEpisode.fromJson(json['next_episode_to_air'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String? ?? 'Returning Series',
      episodeRunTime:
          runTimes.isNotEmpty ? (runTimes.reduce((a, b) => a + b) / runTimes.length).round() : 45,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((g) => (g as Map<String, dynamic>)['name'] as String)
          .toList(),
      overview: json['overview'] as String? ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      firstAirYear:
          (firstAirDate != null && firstAirDate.length >= 4) ? int.parse(firstAirDate.substring(0, 4)) : null,
      lastAirYear:
          (lastAirDate != null && lastAirDate.length >= 4) ? int.parse(lastAirDate.substring(0, 4)) : null,
      specialsEpisodeCount: specials.isEmpty ? 0 : specials.first.episodeCount,
    );
  }
}

class CastMember {
  final String name;
  final String character;
  final String? profilePath;

  CastMember({required this.name, required this.character, required this.profilePath});

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
        name: json['name'] as String,
        character: json['character'] as String? ?? '',
        profilePath: json['profile_path'] as String?,
      );
}

class SimilarMedia {
  final int id;
  final String type; // "tv" | "movie"
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;

  SimilarMedia({
    required this.id,
    required this.type,
    required this.title,
    required this.posterPath,
    this.releaseDate,
  });

  factory SimilarMedia.fromJson(Map<String, dynamic> json, String type) {
    DateTime? releaseDate;
    if (json['release_date'] != null && (json['release_date'] as String).isNotEmpty) {
      try {
        releaseDate = DateTime.parse(json['release_date'] as String);
      } catch (_) {
        releaseDate = null;
      }
    }
    return SimilarMedia(
      id: json['id'] as int,
      type: type,
      title: (type == 'tv' ? json['name'] : json['title']) as String,
      posterPath: json['poster_path'] as String?,
      releaseDate: releaseDate,
    );
  }
}

class EpisodeRef {
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final DateTime? airDate;
  final String overview;
  final String? stillPath;

  EpisodeRef({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    required this.airDate,
    required this.overview,
    required this.stillPath,
  });

  String get key => 's${seasonNumber}e$episodeNumber';

  factory EpisodeRef.fromJson(int seasonNumber, Map<String, dynamic> json) {
    DateTime? airDate;
    if (json['air_date'] != null) {
      try {
        airDate = DateTime.parse(json['air_date'] as String);
      } catch (_) {
        // Ignore malformed dates from TMDB
        airDate = null;
      }
    }
    return EpisodeRef(
      seasonNumber: seasonNumber,
      episodeNumber: json['episode_number'] as int,
      name: json['name'] as String,
      airDate: airDate,
      overview: json['overview'] as String? ?? '',
      stillPath: json['still_path'] as String?,
    );
  }
}

class SeasonDetails {
  final int seasonNumber;
  final List<EpisodeRef> episodes;

  SeasonDetails({required this.seasonNumber, required this.episodes});

  factory SeasonDetails.fromJson(Map<String, dynamic> json) {
    final seasonNumber = json['season_number'] as int;
    final episodes = (json['episodes'] as List<dynamic>)
        .map((e) => EpisodeRef.fromJson(seasonNumber, e as Map<String, dynamic>))
        .toList();
    return SeasonDetails(seasonNumber: seasonNumber, episodes: episodes);
  }
}

class MovieDetails {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final int runtime; // minutes, 0 if unknown
  final List<String> genres;
  final String overview;
  final double voteAverage;

  MovieDetails({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.runtime,
    required this.genres,
    required this.overview,
    required this.voteAverage,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    DateTime? releaseDate;
    if (json['release_date'] != null && (json['release_date'] as String).isNotEmpty) {
      try {
        releaseDate = DateTime.parse(json['release_date'] as String);
      } catch (_) {
        releaseDate = null;
      }
    }
    return MovieDetails(
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: releaseDate,
      runtime: json['runtime'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((g) => (g as Map<String, dynamic>)['name'] as String)
          .toList(),
      overview: json['overview'] as String? ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
    );
  }

class WatchProvider {
  final int id;
  final String name;
  final String? logoPath;

  WatchProvider({required this.id, required this.name, required this.logoPath});

  factory WatchProvider.fromJson(Map<String, dynamic> json) => WatchProvider(
        id: json['provider_id'] as int,
        name: json['provider_name'] as String,
        logoPath: json['logo_path'] as String?,
      );
}

class TitleImages {
  final List<String> backdropPaths;
  final List<String> posterPaths;

  TitleImages({required this.backdropPaths, required this.posterPaths});

  factory TitleImages.fromJson(Map<String, dynamic> json) {
    List<String> paths(String key) => (json[key] as List<dynamic>? ?? [])
        .map((i) => (i as Map<String, dynamic>)['file_path'] as String?)
        .whereType<String>()
        .toList();
    return TitleImages(backdropPaths: paths('backdrops'), posterPaths: paths('posters'));
  }
}
