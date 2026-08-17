import '../models/library_item.dart';
import '../services/tmdb_service.dart';
import '../utils/concurrency.dart';

class YearRecap {
  final int year;
  final int episodesWatched;
  final int moviesWatched;
  final int showsCompleted;
  final int itemsAdded;
  final Duration totalWatchTime;
  final String? topShowTitle;
  final int topShowEpisodeCount;
  final List<int> monthlyActivityCounts; // index 0 = January

  YearRecap({
    required this.year,
    required this.episodesWatched,
    required this.moviesWatched,
    required this.showsCompleted,
    required this.itemsAdded,
    required this.totalWatchTime,
    required this.topShowTitle,
    required this.topShowEpisodeCount,
    required this.monthlyActivityCounts,
  });

  bool get isEmpty => episodesWatched == 0 && moviesWatched == 0;
}

/// Builds a "wrapped"-style recap of the given year from local library data
/// — episode/movie runtimes are fetched from TMDB (once per title) to total
/// watch time. Rewatches count once towards time (no per-rewatch timestamp
/// is kept), but every rewatch within the year still counts as an episode
/// watched via `episodeWatchedAt`.
Future<YearRecap> computeYearRecap({
  required List<LibraryItem> items,
  required TmdbService tmdb,
  required int year,
}) async {
  final tvItems = items.where((i) => i.type == 'tv').toList();
  final movieItems = items.where((i) => i.type == 'movie').toList();
  final monthly = List<int>.filled(12, 0);

  var episodesWatched = 0;
  var showsCompleted = 0;
  final episodeCountByShow = <LibraryItem, int>{};

  for (final item in tvItems) {
    var countThisYear = 0;
    for (final entry in item.episodeWatchedAt.entries) {
      if (entry.value.year != year) continue;
      countThisYear++;
      monthly[entry.value.month - 1]++;
    }
    if (countThisYear > 0) episodeCountByShow[item] = countThisYear;
    episodesWatched += countThisYear;
    if (item.status == 'completed' && item.lastActivityAt?.year == year) showsCompleted++;
  }

  var moviesWatched = 0;
  final moviesThisYear = <LibraryItem>[];
  for (final item in movieItems) {
    if (item.watched && item.watchedAt?.year == year) {
      moviesWatched++;
      moviesThisYear.add(item);
      monthly[item.watchedAt!.month - 1]++;
    }
  }

  final itemsAdded = items.where((i) => i.addedAt.year == year).length;

  LibraryItem? topShow;
  var topShowCount = 0;
  for (final entry in episodeCountByShow.entries) {
    if (entry.value > topShowCount) {
      topShow = entry.key;
      topShowCount = entry.value;
    }
  }

  var totalMinutes = 0;
  String? topShowTitle;
  await forEachBounded(episodeCountByShow.keys.toList(), 6, (item) async {
    try {
      final details = await tmdb.getTvDetails(item.tmdbId);
      totalMinutes += details.episodeRunTime * episodeCountByShow[item]!;
      if (item == topShow) topShowTitle = details.name;
    } catch (_) {}
  });
  await forEachBounded(moviesThisYear, 6, (item) async {
    try {
      final details = await tmdb.getMovieDetails(item.tmdbId);
      totalMinutes += details.runtime;
    } catch (_) {}
  });

  return YearRecap(
    year: year,
    episodesWatched: episodesWatched,
    moviesWatched: moviesWatched,
    showsCompleted: showsCompleted,
    itemsAdded: itemsAdded,
    totalWatchTime: Duration(minutes: totalMinutes),
    topShowTitle: topShowTitle,
    topShowEpisodeCount: topShowCount,
    monthlyActivityCounts: monthly,
  );
}
