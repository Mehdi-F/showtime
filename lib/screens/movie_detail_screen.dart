import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_to_list_sheet.dart';
import '../widgets/media_info_sections.dart';
import 'show_detail_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final LibraryItem? libraryItem;
  final int? previewTmdbId;

  const MovieDetailScreen({super.key, required LibraryItem libraryItem})
      : libraryItem = libraryItem,
        previewTmdbId = null;

  /// Shows a movie's details without adding it to the library. Use when the
  /// user is just browsing (e.g. Explorer, recommendations) — following only
  /// happens when they tap "Suivre" or an action that requires it.
  const MovieDetailScreen.preview({super.key, required int tmdbId})
      : libraryItem = null,
        previewTmdbId = tmdbId;

  int get tmdbId => libraryItem?.tmdbId ?? previewTmdbId!;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  LibraryItem? _libraryItem;
  bool _watched = false;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _libraryItem = widget.libraryItem;
    _watched = widget.libraryItem?.watched ?? false;
    _favorite = widget.libraryItem?.favorite ?? false;
  }

  Future<LibraryItem> _ensureFollowed() async {
    final current = _libraryItem;
    if (current != null) return current;
    final uid = context.read<AuthProvider>().user!.uid;
    final item = await context.read<LibraryService>().addToLibrary(
          uid: uid,
          tmdbId: widget.tmdbId,
          type: 'movie',
        );
    if (mounted) setState(() => _libraryItem = item);
    return item;
  }

  Future<void> _toggleWatched() async {
    final item = await _ensureFollowed();
    final newValue = !_watched;
    setState(() => _watched = newValue);
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().markMovieWatched(
          uid: uid,
          tmdbId: item.tmdbId,
          watched: newValue,
        );
  }

  Future<void> _toggleFavorite() async {
    final item = await _ensureFollowed();
    final newValue = !_favorite;
    setState(() => _favorite = newValue);
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().toggleFavorite(
          uid: uid,
          tmdbId: item.tmdbId,
          type: 'movie',
          favorite: newValue,
        );
  }

  Future<void> _unfollow() async {
    final item = _libraryItem;
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().removeFromLibrary(
          uid: uid,
          tmdbId: item.tmdbId,
          type: 'movie',
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _openSimilar(SimilarMedia media) async {
    final matches = context
        .read<LibraryProvider>()
        .items
        .where((i) => i.tmdbId == media.id && i.type == media.type);
    if (!mounted) return;
    if (matches.isNotEmpty) {
      final item = matches.first;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            media.type == 'tv' ? ShowDetailScreen(libraryItem: item) : MovieDetailScreen(libraryItem: item),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => media.type == 'tv'
            ? ShowDetailScreen.preview(tmdbId: media.id)
            : MovieDetailScreen.preview(tmdbId: media.id),
      ));
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<TmdbService>().getMovieDetails(widget.tmdbId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final movie = snapshot.data!;
        final tmdb = context.read<TmdbService>();
        final followed = _libraryItem != null;
        return Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (movie.posterPath != null)
                      CachedNetworkImage(
                        imageUrl: '${TmdbConfig.imageBaseUrl}${movie.posterPath}',
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: AppColors.surfaceVariant),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 4,
                      right: 4,
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            Row(
                              children: [
                                if (followed)
                                  IconButton(
                                    icon: Icon(
                                      _favorite ? Icons.favorite : Icons.favorite_border,
                                      color: _favorite ? Colors.redAccent : Colors.white,
                                    ),
                                    onPressed: _toggleFavorite,
                                  ),
                                if (followed)
                                  PopupMenuButton<void>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    color: AppColors.surface,
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        onTap: () => showAddToListSheet(
                                          context,
                                          tmdbId: widget.tmdbId,
                                          type: 'movie',
                                        ),
                                        child: const Text('Ajouter à une liste'),
                                      ),
                                      PopupMenuItem(
                                        onTap: _unfollow,
                                        child: const Text('Remove from Library'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: followed
                    ? FilledButton.icon(
                        onPressed: _toggleWatched,
                        icon: Icon(_watched ? Icons.check_circle : Icons.check_circle_outline),
                        label: Text(_watched ? 'Watched' : 'Mark watched'),
                      )
                    : FilledButton.icon(
                        onPressed: _ensureFollowed,
                        icon: const Icon(Icons.add),
                        label: const Text('Suivre'),
                      ),
              ),
              InfoCard(
                yearRange: movie.releaseDate?.year.toString(),
                genres: movie.genres,
                voteAverage: movie.voteAverage,
                overview: movie.overview,
                runtimeMinutes: movie.runtime,
                addedCaption: followed
                    ? 'Ajouté à votre bibliothèque le ${_formatDate(_libraryItem!.addedAt)}'
                    : 'Pas encore suivi',
              ),
              CastRow(future: tmdb.getMovieCredits(widget.tmdbId)),
              SimilarRow(
                title: 'Les utilisateurs ont également regardé',
                future: tmdb.getSimilarMovies(widget.tmdbId),
                onTap: _openSimilar,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
