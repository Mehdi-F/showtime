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

  factory NextEpisode.fromJson(Map<String, dynamic> json) => NextEpisode(
        seasonNumber: json['season_number'] as int,
        episodeNumber: json['episode_number'] as int,
        name: json['name'] as String,
        airDate: json['air_date'] != null ? DateTime.parse(json['air_date'] as String) : null,
      );
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

  SimilarMedia({required this.id, required this.type, required this.title, required this.posterPath});

  factory SimilarMedia.fromJson(Map<String, dynamic> json, String type) => SimilarMedia(
        id: json['id'] as int,
        type: type,
        title: (type == 'tv' ? json['name'] : json['title']) as String,
        posterPath: json['poster_path'] as String?,
      );
}

class EpisodeRef {
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final DateTime? airDate;

  EpisodeRef({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    required this.airDate,
  });

  String get key => 's${seasonNumber}e$episodeNumber';

  factory EpisodeRef.fromJson(int seasonNumber, Map<String, dynamic> json) => EpisodeRef(
        seasonNumber: seasonNumber,
        episodeNumber: json['episode_number'] as int,
        name: json['name'] as String,
        airDate: json['air_date'] != null ? DateTime.parse(json['air_date'] as String) : null,
      );
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

  factory MovieDetails.fromJson(Map<String, dynamic> json) => MovieDetails(
        id: json['id'] as int,
        title: json['title'] as String,
        posterPath: json['poster_path'] as String?,
        backdropPath: json['backdrop_path'] as String?,
        releaseDate:
            json['release_date'] != null && (json['release_date'] as String).isNotEmpty
                ? DateTime.parse(json['release_date'] as String)
                : null,
        runtime: json['runtime'] as int? ?? 0,
        genres: (json['genres'] as List<dynamic>? ?? [])
            .map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList(),
        overview: json['overview'] as String? ?? '',
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      );
}
