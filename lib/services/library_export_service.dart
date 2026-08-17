import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/library_item.dart';
import '../utils/concurrency.dart';
import 'tmdb_service.dart';

/// Builds a CSV export of the library, one row per item. Titles are
/// resolved from TMDB (library items only store the tmdbId); rows for
/// items whose TMDB lookup fails still export, with a placeholder title.
Future<List<int>> buildLibraryCsvBytes({
  required List<LibraryItem> items,
  required TmdbService tmdb,
  required List<String> header,
  required String tvTypeLabel,
  required String movieTypeLabel,
  required String Function(String status) statusLabel,
  required String Function(bool value) yesNo,
}) async {
  final rows = List<List<dynamic>?>.filled(items.length, null);

  await forEachBounded(List.generate(items.length, (i) => i), 6, (i) async {
    final item = items[i];
    var title = 'tmdb:${item.tmdbId}';
    int? totalEpisodes;
    try {
      if (item.type == 'tv') {
        final details = await tmdb.getTvDetails(item.tmdbId);
        title = details.name;
        totalEpisodes =
            details.seasons.where((s) => s.seasonNumber >= 1).fold<int>(0, (sum, s) => sum + s.episodeCount);
      } else {
        final details = await tmdb.getMovieDetails(item.tmdbId);
        title = details.title;
      }
    } catch (_) {
      // Keep the placeholder title rather than dropping the row.
    }

    if (item.type == 'tv') {
      final watchedCount = item.watchedEpisodes.values.where((w) => w).length;
      final rewatches = item.episodeRewatchCounts.values.fold(0, (a, b) => a + b);
      final done = totalEpisodes != null && totalEpisodes > 0 && watchedCount >= totalEpisodes;
      rows[i] = [
        tvTypeLabel,
        title,
        statusLabel(item.status),
        item.addedAt.toIso8601String().split('T').first,
        yesNo(item.favorite),
        yesNo(done),
        watchedCount,
        totalEpisodes ?? '',
        rewatches,
      ];
    } else {
      rows[i] = [
        movieTypeLabel,
        title,
        statusLabel(item.status),
        item.addedAt.toIso8601String().split('T').first,
        yesNo(item.favorite),
        yesNo(item.watched),
        item.watched ? 1 : 0,
        1,
        item.movieRewatchCount,
      ];
    }
  });

  final csv = const ListToCsvConverter().convert([header, ...rows.cast<List<dynamic>>()]);
  return utf8.encode(csv);
}
