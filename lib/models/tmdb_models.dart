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
  final List<SeasonSummary> seasons;
  final NextEpisode? nextEpisodeToAir;
  final String status; // TMDB raw value: "Returning Series" | "Ended" | "Canceled" | "In Production" | "Planned" | "Pilot"

  TvDetails({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.seasons,
    required this.nextEpisodeToAir,
    required this.status,
  });

  bool get isEnded => status == 'Ended' || status == 'Canceled';

  factory TvDetails.fromJson(Map<String, dynamic> json) => TvDetails(
        id: json['id'] as int,
        name: json['name'] as String,
        posterPath: json['poster_path'] as String?,
        seasons: (json['seasons'] as List<dynamic>? ?? [])
            // TMDB includes a "Specials" entry as season_number 0 — skip it, MVP only tracks numbered seasons.
            .map((s) => SeasonSummary.fromJson(s as Map<String, dynamic>))
            .where((s) => s.seasonNumber > 0)
            .toList(),
        nextEpisodeToAir: json['next_episode_to_air'] != null
            ? NextEpisode.fromJson(json['next_episode_to_air'] as Map<String, dynamic>)
            : null,
        status: json['status'] as String? ?? 'Returning Series',
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
  final DateTime? releaseDate;

  MovieDetails({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseDate,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) => MovieDetails(
        id: json['id'] as int,
        title: json['title'] as String,
        posterPath: json['poster_path'] as String?,
        releaseDate:
            json['release_date'] != null && (json['release_date'] as String).isNotEmpty
                ? DateTime.parse(json['release_date'] as String)
                : null,
      );
}
