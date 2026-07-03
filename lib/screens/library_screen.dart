import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<(String title, String? posterPath)> _resolveMeta(
      BuildContext context, LibraryItem item) async {
    final tmdb = context.read<TmdbService>();
    if (item.type == 'tv') {
      final details = await tmdb.getTvDetails(item.tmdbId);
      return (details.name, details.posterPath);
    } else {
      final details = await tmdb.getMovieDetails(item.tmdbId);
      return (details.title, details.posterPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<LibraryProvider>().items;

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Nothing tracked yet — add shows from Search.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return FutureBuilder<(String title, String? posterPath)>(
                  future: _resolveMeta(context, item),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const MediaListTile(posterPath: null, title: '…');
                    }
                    final (title, posterPath) = snapshot.data!;
                    return MediaListTile(
                      posterPath: posterPath,
                      title: title,
                      subtitle: item.type == 'tv' ? 'Series' : 'Film',
                      trailing: item.type == 'movie' && item.watched
                          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => item.type == 'tv'
                              ? ShowDetailScreen(libraryItem: item)
                              : MovieDetailScreen(libraryItem: item),
                        ));
                      },
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          TmdbConfig.attribution,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
