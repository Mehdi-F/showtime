import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/up_next.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';

class _UpNextRow {
  final String showTitle;
  final String? posterPath;
  final EpisodeRef episode;

  _UpNextRow({required this.showTitle, required this.posterPath, required this.episode});
}

class UpNextScreen extends StatelessWidget {
  const UpNextScreen({super.key});

  Future<_UpNextRow?> _resolveRow(TmdbService tmdb, LibraryItem item) async {
    final details = await tmdb.getTvDetails(item.tmdbId);
    final allEpisodes = <EpisodeRef>[];
    for (final season in details.seasons) {
      final seasonDetails = await tmdb.getSeasonDetails(item.tmdbId, season.seasonNumber);
      allEpisodes.addAll(seasonDetails.episodes);
    }
    final next = nextUnwatchedEpisode(
      episodesInOrder: allEpisodes,
      watchedEpisodes: item.watchedEpisodes,
      now: DateTime.now(),
    );
    if (next == null) return null;
    return _UpNextRow(showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Up Next')),
      body: tvItems.isEmpty
          ? const Center(
              child: Text(
                'Track a show from Search to see it here.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : FutureBuilder<List<_UpNextRow?>>(
              future: Future.wait(tvItems.map((item) => _resolveRow(tmdb, item))),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!.whereType<_UpNextRow>().toList();
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return MediaListTile(
                      posterPath: row.posterPath,
                      title: row.showTitle,
                      subtitle:
                          'S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}',
                    );
                  },
                );
              },
            ),
    );
  }
}
