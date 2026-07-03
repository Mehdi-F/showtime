import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';

class _CalendarRow {
  final String showTitle;
  final String? posterPath;
  final NextEpisode episode;

  _CalendarRow({required this.showTitle, required this.posterPath, required this.episode});
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  Future<_CalendarRow?> _resolveRow(TmdbService tmdb, int tmdbId) async {
    final details = await tmdb.getTvDetails(tmdbId);
    final next = details.nextEpisodeToAir;
    if (next == null) return null;
    return _CalendarRow(showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: tvItems.isEmpty
          ? const Center(
              child: Text(
                'Track a show from Search to see upcoming episodes.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : FutureBuilder<List<_CalendarRow?>>(
              future: Future.wait(tvItems.map((item) => _resolveRow(tmdb, item.tmdbId))),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!.whereType<_CalendarRow>().toList()
                  ..sort((a, b) {
                    final aDate = a.episode.airDate;
                    final bDate = b.episode.airDate;
                    if (aDate == null && bDate == null) return 0;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return aDate.compareTo(bDate);
                  });
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No upcoming episodes scheduled.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final date = row.episode.airDate;
                    return MediaListTile(
                      posterPath: row.posterPath,
                      title: row.showTitle,
                      subtitle:
                          'S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}',
                      trailing: Text(
                        date != null ? dateFormat.format(date) : 'TBA',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
