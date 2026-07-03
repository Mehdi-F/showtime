import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

class _ResolvedItem {
  final LibraryItem item;
  final String title;
  final String? posterPath;

  _ResolvedItem({required this.item, required this.title, required this.posterPath});
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<_ResolvedItem> _resolve(TmdbService tmdb, LibraryItem item) async {
    if (item.type == 'tv') {
      final details = await tmdb.getTvDetails(item.tmdbId);
      return _ResolvedItem(item: item, title: details.name, posterPath: details.posterPath);
    } else {
      final details = await tmdb.getMovieDetails(item.tmdbId);
      return _ResolvedItem(item: item, title: details.title, posterPath: details.posterPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<LibraryProvider>().items;
    final tmdb = context.read<TmdbService>();
    final user = context.watch<AuthProvider>().user;

    final series = items.where((i) => i.type == 'tv').toList();
    final seriesFav = series.where((i) => i.favorite).toList();
    final films = items.where((i) => i.type == 'movie').toList();
    final filmsFav = films.where((i) => i.favorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (user?.email != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(user!.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          _CarouselSection(title: 'Séries', items: series, tmdb: tmdb, resolve: _resolve),
          _CarouselSection(title: 'Séries préférées', items: seriesFav, tmdb: tmdb, resolve: _resolve),
          _CarouselSection(title: 'Films', items: films, tmdb: tmdb, resolve: _resolve),
          _CarouselSection(title: 'Films préférés', items: filmsFav, tmdb: tmdb, resolve: _resolve),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              TmdbConfig.attribution,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselSection extends StatelessWidget {
  final String title;
  final List<LibraryItem> items;
  final TmdbService tmdb;
  final Future<_ResolvedItem> Function(TmdbService, LibraryItem) resolve;

  const _CarouselSection({
    required this.title,
    required this.items,
    required this.tmdb,
    required this.resolve,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return FutureBuilder<_ResolvedItem>(
                future: resolve(tmdb, item),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(width: 90);
                  }
                  final resolved = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => item.type == 'tv'
                              ? ShowDetailScreen(libraryItem: item)
                              : MovieDetailScreen(libraryItem: item),
                        ));
                      },
                      child: SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: resolved.posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: '${TmdbConfig.imageBaseUrl}${resolved.posterPath}',
                                  fit: BoxFit.cover,
                                  height: 130,
                                  width: 90,
                                )
                              : Container(
                                  color: AppColors.surfaceVariant,
                                  height: 130,
                                  width: 90,
                                  child: const Icon(Icons.tv, color: AppColors.textSecondary),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
