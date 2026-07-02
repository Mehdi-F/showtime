class LibraryItem {
  final String docId;
  final int tmdbId;
  final String type; // "tv" | "movie"
  final String status; // "watching" | "completed" | "plan_to_watch"
  final DateTime addedAt;
  final Map<String, bool> watchedEpisodes; // tv only, key = "s{season}e{episode}"
  final bool watched; // movie only
  final DateTime? watchedAt; // movie only

  LibraryItem({
    required this.docId,
    required this.tmdbId,
    required this.type,
    required this.status,
    required this.addedAt,
    required this.watchedEpisodes,
    required this.watched,
    required this.watchedAt,
  });

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
      );

  Map<String, dynamic> toMap() => {
        'tmdbId': tmdbId,
        'type': type,
        'status': status,
        'addedAt': addedAt.toIso8601String(),
        'watchedEpisodes': watchedEpisodes,
        'watched': watched,
        'watchedAt': watchedAt?.toIso8601String(),
      };
}
