import '../models/library_item.dart';
import '../services/tmdb_service.dart';
import '../utils/concurrency.dart';

class CommonTitle {
  final String type; // "tv" | "movie"
  final int tmdbId;
  final String title;
  final String? posterPath;
  final int myCount;
  final int friendCount;
  final int total; // total episodes for tv, always 1 for movies

  CommonTitle({
    required this.type,
    required this.tmdbId,
    required this.title,
    required this.posterPath,
    required this.myCount,
    required this.friendCount,
    required this.total,
  });
}

class ComparisonResult {
  final int myEpisodes;
  final int friendEpisodes;
  final int myMovies;
  final int friendMovies;
  final List<CommonTitle> commonTitles;

  ComparisonResult({
    required this.myEpisodes,
    required this.friendEpisodes,
    required this.myMovies,
    required this.friendMovies,
    required this.commonTitles,
  });
}

int _episodesWatched(LibraryItem item) => item.watchedEpisodes.values.where((w) => w).length;

/// Compares two libraries: aggregate totals plus per-title progress for
/// whatever the two users both follow (same type + tmdbId).
Future<ComparisonResult> computeFriendComparison({
  required List<LibraryItem> myItems,
  required List<LibraryItem> friendItems,
  required TmdbService tmdb,
}) async {
  String key(LibraryItem i) => '${i.type}:${i.tmdbId}';
  final myByKey = {for (final i in myItems) key(i): i};
  final friendByKey = {for (final i in friendItems) key(i): i};
  final commonKeys = myByKey.keys.toSet().intersection(friendByKey.keys.toSet()).toList();

  final myEpisodes = myItems.where((i) => i.type == 'tv').fold<int>(0, (s, i) => s + _episodesWatched(i));
  final friendEpisodes = friendItems.where((i) => i.type == 'tv').fold<int>(0, (s, i) => s + _episodesWatched(i));
  final myMovies = myItems.where((i) => i.type == 'movie' && i.watched).length;
  final friendMovies = friendItems.where((i) => i.type == 'movie' && i.watched).length;

  final common = List<CommonTitle?>.filled(commonKeys.length, null);
  await forEachBounded(List.generate(commonKeys.length, (i) => i), 6, (i) async {
    final k = commonKeys[i];
    final mine = myByKey[k]!;
    final theirs = friendByKey[k]!;
    try {
      if (mine.type == 'tv') {
        final details = await tmdb.getTvDetails(mine.tmdbId);
        final total = details.seasons.where((s) => s.seasonNumber >= 1).fold<int>(0, (s, se) => s + se.episodeCount);
        common[i] = CommonTitle(
          type: 'tv',
          tmdbId: mine.tmdbId,
          title: details.name,
          posterPath: details.posterPath,
          myCount: _episodesWatched(mine),
          friendCount: _episodesWatched(theirs),
          total: total,
        );
      } else {
        final details = await tmdb.getMovieDetails(mine.tmdbId);
        common[i] = CommonTitle(
          type: 'movie',
          tmdbId: mine.tmdbId,
          title: details.title,
          posterPath: details.posterPath,
          myCount: mine.watched ? 1 : 0,
          friendCount: theirs.watched ? 1 : 0,
          total: 1,
        );
      }
    } catch (_) {}
  });

  final commonTitles = common.whereType<CommonTitle>().toList()..sort((a, b) => a.title.compareTo(b.title));

  return ComparisonResult(
    myEpisodes: myEpisodes,
    friendEpisodes: friendEpisodes,
    myMovies: myMovies,
    friendMovies: friendMovies,
    commonTitles: commonTitles,
  );
}
