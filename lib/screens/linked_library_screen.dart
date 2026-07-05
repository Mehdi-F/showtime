import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';

class _ResolvedPartnerItem {
  final LibraryItem item;
  final String title;
  final String? posterPath;
  final int totalEpisodeCount;

  _ResolvedPartnerItem({
    required this.item,
    required this.title,
    required this.posterPath,
    this.totalEpisodeCount = 0,
  });

  int get watchedEpisodesCount => item.watchedEpisodes.values.where((w) => w).length;

  bool get isWatched =>
      item.type == 'movie' ? item.watched : (totalEpisodeCount > 0 && watchedEpisodesCount >= totalEpisodeCount);

  double? get progress {
    if (item.type == 'movie' || totalEpisodeCount <= 0) return null;
    return watchedEpisodesCount / totalEpisodeCount;
  }
}

/// Read-only view of a linked partner's library — no toggling, no
/// navigation into the detail screens (those write under the *current*
/// user's uid, which would be wrong here).
class LinkedLibraryScreen extends StatelessWidget {
  final String partnerUid;
  final String partnerName;

  const LinkedLibraryScreen({super.key, required this.partnerUid, required this.partnerName});

  Future<_ResolvedPartnerItem> _resolve(TmdbService tmdb, LibraryItem item) async {
    if (item.type == 'tv') {
      final details = await tmdb.getTvDetails(item.tmdbId);
      final total = details.seasons.fold<int>(0, (sum, s) => sum + s.episodeCount);
      return _ResolvedPartnerItem(
          item: item, title: details.name, posterPath: details.posterPath, totalEpisodeCount: total);
    }
    final details = await tmdb.getMovieDetails(item.tmdbId);
    return _ResolvedPartnerItem(item: item, title: details.title, posterPath: details.posterPath);
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
      );

  Widget _buildRow(_ResolvedPartnerItem r) {
    final progress = r.progress;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 46,
          height: 64,
          child: r.posterPath != null
              ? CachedNetworkImage(imageUrl: '${TmdbConfig.imageBaseUrl}${r.posterPath}', fit: BoxFit.cover)
              : Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary, size: 18),
                ),
        ),
      ),
      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: progress != null
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.green : AppColors.accent),
                ),
              ),
            )
          : null,
      trailing: Icon(
        r.isWatched ? Icons.check_circle : Icons.radio_button_unchecked,
        color: r.isWatched ? Colors.green : AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryService>();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(title: Text('Bibliothèque de $partnerName')),
      body: StreamBuilder<List<LibraryItem>>(
        stream: library.watchLibrary(partnerUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child:
                  Text('Aucun contenu suivi pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return FutureBuilder<List<_ResolvedPartnerItem>>(
            future: Future.wait(items.map((i) => _resolve(tmdb, i))),
            builder: (context, resolvedSnapshot) {
              final resolved = resolvedSnapshot.data;
              if (resolved == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final series = resolved.where((r) => r.item.type == 'tv').toList()
                ..sort((a, b) => b.item.addedAt.compareTo(a.item.addedAt));
              final films = resolved.where((r) => r.item.type == 'movie').toList()
                ..sort((a, b) => b.item.addedAt.compareTo(a.item.addedAt));

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (series.isNotEmpty) _sectionHeader('Séries (${series.length})'),
                  ...series.map(_buildRow),
                  if (films.isNotEmpty) _sectionHeader('Films (${films.length})'),
                  ...films.map(_buildRow),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
