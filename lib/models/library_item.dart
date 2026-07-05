class LibraryItem {
  final String docId;
  final int tmdbId;
  final String type; // "tv" | "movie"
  final String status; // "watching" | "completed" | "plan_to_watch"
  final DateTime addedAt;
  final Map<String, bool> watchedEpisodes; // tv only, key = "s{season}e{episode}"
  final bool watched; // movie only
  final DateTime? watchedAt; // movie only
  final bool favorite;
  final DateTime? lastActivityAt; // tv only, bumped on episode/season watch toggles
  final bool skipGapPrompt; // tv only, "never ask again" for the previous-episodes dialog
  final Map<String, int> episodeRewatchCounts; // tv only, key = "s{season}e{episode}"
  final Map<String, DateTime> episodeWatchedAt; // tv only, key = "s{season}e{episode}"
  final int movieRewatchCount; // movie only

  LibraryItem({
    required this.docId,
    required this.tmdbId,
    required this.type,
    required this.status,
    required this.addedAt,
    required this.watchedEpisodes,
    required this.watched,
    required this.watchedAt,
    this.favorite = false,
    this.lastActivityAt,
    this.skipGapPrompt = false,
    this.episodeRewatchCounts = const {},
    this.episodeWatchedAt = const {},
    this.movieRewatchCount = 0,
  });

  LibraryItem copyWith({bool? skipGapPrompt}) => LibraryItem(
        docId: docId,
        tmdbId: tmdbId,
        type: type,
        status: status,
        addedAt: addedAt,
        watchedEpisodes: watchedEpisodes,
        watched: watched,
        watchedAt: watchedAt,
        favorite: favorite,
        lastActivityAt: lastActivityAt,
        skipGapPrompt: skipGapPrompt ?? this.skipGapPrompt,
        episodeRewatchCounts: episodeRewatchCounts,
        episodeWatchedAt: episodeWatchedAt,
        movieRewatchCount: movieRewatchCount,
      );

  static String buildDocId({required int tmdbId, required String type}) => '${type}_$tmdbId';

  factory LibraryItem.fromMap(String docId, Map<String, dynamic> map) => LibraryItem(
        docId: docId,
        tmdbId: map['tmdbId'] as int,
        type: map['type'] as String,
        status: map['status'] as String,
        addedAt: DateTime.parse(map['addedAt'] as String),
        watchedEpisodes: Map<String, bool>.from(map['watchedEpisodes'] as Map? ?? {}),
        watched: map['watched'] as bool? ?? false,
        watchedAt: map['watchedAt'] != null ? DateTime.parse(map['watchedAt'] as String) : null,
        favorite: map['favorite'] as bool? ?? false,
        lastActivityAt:
            map['lastActivityAt'] != null ? DateTime.parse(map['lastActivityAt'] as String) : null,
        skipGapPrompt: map['skipGapPrompt'] as bool? ?? false,
        episodeRewatchCounts: (map['episodeRewatchCounts'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        episodeWatchedAt: (map['episodeWatchedAt'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, DateTime.parse(v as String))),
        movieRewatchCount: (map['movieRewatchCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'tmdbId': tmdbId,
        'type': type,
        'status': status,
        'addedAt': addedAt.toIso8601String(),
        'watchedEpisodes': watchedEpisodes,
        'watched': watched,
        'watchedAt': watchedAt?.toIso8601String(),
        'favorite': favorite,
        'lastActivityAt': lastActivityAt?.toIso8601String(),
        'skipGapPrompt': skipGapPrompt,
        'episodeRewatchCounts': episodeRewatchCounts,
        'episodeWatchedAt': episodeWatchedAt.map((k, v) => MapEntry(k, v.toIso8601String())),
        'movieRewatchCount': movieRewatchCount,
      };
}
