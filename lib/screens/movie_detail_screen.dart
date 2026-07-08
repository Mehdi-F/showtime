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
import '../widgets/add_bar.dart';
import '../widgets/add_to_list_sheet.dart';
import '../widgets/app_page_route.dart';
import '../widgets/media_info_sections.dart';
import '../widgets/poster_hero_tag.dart';
import '../widgets/round_check.dart';
import '../widgets/skeletons.dart';
import 'show_detail_screen.dart';

enum _RewatchChoice { notWatched, rewatch }

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
  int _rewatchCount = 0;
  late Future<MovieDetails> _detailsFuture;

  // Fetched once and reused across rebuilds — building these inline inside
  // _buildBody would re-hit TMDB on every setState in this screen (e.g. every
  // toggleWatched/toggleFavorite tap).
  late Future<List<WatchProvider>> _watchProvidersFuture;
  late Future<List<CastMember>> _creditsFuture;
  late Future<List<SimilarMedia>> _similarFuture;

  @override
  void initState() {
    super.initState();
    _libraryItem = widget.libraryItem;
    _watched = widget.libraryItem?.watched ?? false;
    _favorite = widget.libraryItem?.favorite ?? false;
    _rewatchCount = widget.libraryItem?.movieRewatchCount ?? 0;
    final tmdb = context.read<TmdbService>();
    _detailsFuture = tmdb.getMovieDetails(widget.tmdbId);
    _watchProvidersFuture = tmdb.getMovieWatchProviders(widget.tmdbId);
    _creditsFuture = tmdb.getMovieCredits(widget.tmdbId);
    _similarFuture = tmdb.getSimilarMovies(widget.tmdbId);
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Échec de la sauvegarde. Réessaie.')),
    );
  }

  Future<void> _retryLoad() async {
    final tmdb = context.read<TmdbService>();
    tmdb.clearCache();
    final future = tmdb.getMovieDetails(widget.tmdbId);
    setState(() {
      _detailsFuture = future;
      _watchProvidersFuture = tmdb.getMovieWatchProviders(widget.tmdbId);
      _creditsFuture = tmdb.getMovieCredits(widget.tmdbId);
      _similarFuture = tmdb.getSimilarMovies(widget.tmdbId);
    });
    await future;
  }

  LibraryItem _withUpdates(LibraryItem item, {required bool watched, required DateTime? watchedAt}) =>
      LibraryItem(
        docId: item.docId,
        tmdbId: item.tmdbId,
        type: item.type,
        status: item.status,
        addedAt: item.addedAt,
        watchedEpisodes: item.watchedEpisodes,
        watched: watched,
        watchedAt: watchedAt,
        favorite: item.favorite,
        lastActivityAt: item.lastActivityAt,
        skipGapPrompt: item.skipGapPrompt,
        episodeRewatchCounts: item.episodeRewatchCounts,
        episodeWatchedAt: item.episodeWatchedAt,
        movieRewatchCount: _rewatchCount,
      );

  Future<_RewatchChoice?> _askRewatchChoice() {
    return showDialog<_RewatchChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Marquer comme...'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_RewatchChoice.notWatched),
            child: const Row(children: [
              Icon(Icons.visibility_off_outlined, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Text('Pas vu'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_RewatchChoice.rewatch),
            child: const Row(children: [
              Icon(Icons.replay, color: AppColors.accent),
              SizedBox(width: 12),
              Text('+1 Revu'),
            ]),
          ),
        ],
      ),
    );
  }

  Future<LibraryItem?> _ensureFollowed() async {
    final current = _libraryItem;
    if (current != null) return current;
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      final item = await context.read<LibraryService>().addToLibrary(
            uid: uid,
            tmdbId: widget.tmdbId,
            type: 'movie',
          );
      if (mounted) setState(() => _libraryItem = item);
      return item;
    } catch (_) {
      _showSaveError();
      return null;
    }
  }

  Future<void> _toggleWatched() async {
    final item = await _ensureFollowed();
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final library = context.read<LibraryService>();

    if (_watched) {
      final choice = await _askRewatchChoice();
      if (!mounted || choice == null) return;
      if (choice == _RewatchChoice.rewatch) {
        final previousCount = _rewatchCount;
        final previousItem = _libraryItem;
        final now = DateTime.now();
        setState(() {
          _rewatchCount++;
          _libraryItem = _withUpdates(item, watched: true, watchedAt: now);
        });
        try {
          await library.incrementMovieRewatch(uid: uid, tmdbId: item.tmdbId);
        } catch (_) {
          if (mounted) {
            setState(() {
              _rewatchCount = previousCount;
              _libraryItem = previousItem;
            });
          }
          _showSaveError();
        }
        return;
      }
      final previousItem = _libraryItem;
      setState(() {
        _watched = false;
        _libraryItem = _withUpdates(item, watched: false, watchedAt: null);
      });
      try {
        await library.markMovieWatched(uid: uid, tmdbId: item.tmdbId, watched: false);
      } catch (_) {
        if (mounted) {
          setState(() {
            _watched = true;
            _libraryItem = previousItem;
          });
        }
        _showSaveError();
      }
      return;
    }

    final now = DateTime.now();
    final previousItem = _libraryItem;
    setState(() {
      _watched = true;
      _libraryItem = _withUpdates(item, watched: true, watchedAt: now);
    });
    try {
      await library.markMovieWatched(uid: uid, tmdbId: item.tmdbId, watched: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _watched = false;
          _libraryItem = previousItem;
        });
      }
      _showSaveError();
    }
  }

  Future<void> _toggleFavorite() async {
    final item = await _ensureFollowed();
    if (item == null) return;
    final newValue = !_favorite;
    final previous = _favorite;
    setState(() => _favorite = newValue);
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      await context.read<LibraryService>().toggleFavorite(
            uid: uid,
            tmdbId: item.tmdbId,
            type: 'movie',
            favorite: newValue,
          );
    } catch (_) {
      if (mounted) setState(() => _favorite = previous);
      _showSaveError();
    }
  }

  Future<void> _unfollow() async {
    final item = _libraryItem;
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      await context.read<LibraryService>().removeFromLibrary(
            uid: uid,
            tmdbId: item.tmdbId,
            type: 'movie',
          );
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      _showSaveError();
    }
  }

  Future<void> _openSimilar(SimilarMedia media) async {
    final matches = context
        .read<LibraryProvider>()
        .items
        .where((i) => i.tmdbId == media.id && i.type == media.type);
    if (!mounted) return;
    if (matches.isNotEmpty) {
      final item = matches.first;
      Navigator.of(context).push(appRoute(
        builder: (_) =>
            media.type == 'tv' ? ShowDetailScreen(libraryItem: item) : MovieDetailScreen(libraryItem: item),
      ));
    } else {
      Navigator.of(context).push(appRoute(
        builder: (_) => media.type == 'tv'
            ? ShowDetailScreen.preview(tmdbId: media.id)
            : MovieDetailScreen.preview(tmdbId: media.id),
      ));
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildWatchedCard() {
    final watchedAt = _libraryItem?.watchedAt;
    return GestureDetector(
      onTap: _toggleWatched,
      child: Container(
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_watched ? 'Vu' : 'Pas encore vu',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    _watched && watchedAt != null
                        ? [
                            'Vu le ${_formatDate(watchedAt)}',
                            if (_rewatchCount > 0) '+$_rewatchCount revu${_rewatchCount > 1 ? "s" : ""}',
                          ].join(' · ')
                        : 'Marquez-le comme vu une fois terminé.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RoundCheck(checked: _watched, onTap: _toggleWatched),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(MovieDetails movie) {
    final libraryItem = _libraryItem;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('VISIONNAGE',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildWatchedCard(),
        ),
        WatchProvidersRow(future: _watchProvidersFuture),
        InfoCard(
          yearRange: movie.releaseDate?.year.toString(),
          genres: movie.genres,
          voteAverage: movie.voteAverage,
          overview: movie.overview,
          runtimeMinutes: movie.runtime,
          addedCaption: libraryItem != null
              ? 'Ajouté à votre bibliothèque le ${_formatDate(libraryItem.addedAt)}'
              : 'Pas encore suivi',
        ),
        CastRow(future: _creditsFuture),
        SimilarRow(
          title: 'Vous pourriez aussi aimer',
          future: _similarFuture,
          onTap: _openSimilar,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovieDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Impossible de charger ce film.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retryLoad, child: const Text('Réessayer')),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: DetailScreenSkeleton());
        }
        final movie = snapshot.data!;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _retryLoad,
            child: Column(
              children: [
                _MovieBanner(
                  heroTag: posterHeroTag('movie', widget.tmdbId),
                  title: movie.title,
                  posterPath: movie.posterPath,
                  runtimeMinutes: movie.runtime,
                  genres: movie.genres,
                  favorite: _favorite,
                  followed: _libraryItem != null,
                  onToggleFavorite: _toggleFavorite,
                  onUnfollow: _unfollow,
                  onAddToList: () => showAddToListSheet(
                    context,
                    tmdbId: widget.tmdbId,
                    type: 'movie',
                  ),
                ),
                Expanded(child: _buildBody(movie)),
              ],
            ),
          ),
          bottomNavigationBar:
              _libraryItem == null ? AddBar(label: 'AJOUTER LE FILM', onTap: _ensureFollowed) : null,
        );
      },
    );
  }
}

class _MovieBanner extends StatelessWidget {
  final String heroTag;
  final String title;
  final String? posterPath;
  final int runtimeMinutes;
  final List<String> genres;
  final bool favorite;
  final bool followed;
  final VoidCallback onToggleFavorite;
  final VoidCallback onUnfollow;
  final VoidCallback onAddToList;

  const _MovieBanner({
    required this.heroTag,
    required this.title,
    required this.posterPath,
    required this.runtimeMinutes,
    required this.genres,
    required this.favorite,
    required this.followed,
    required this.onToggleFavorite,
    required this.onUnfollow,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: heroTag,
            child: posterPath != null
                ? CachedNetworkImage(
                    imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                    fit: BoxFit.cover,
                  )
                : Container(color: AppColors.surfaceVariant),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.85)],
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
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(favorite),
                              color: favorite ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          onPressed: onToggleFavorite,
                        ),
                      if (followed)
                        PopupMenuButton<void>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: AppColors.surface,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              onTap: onAddToList,
                              child: const Text('Ajouter à une liste'),
                            ),
                            PopupMenuItem(
                              onTap: onUnfollow,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (runtimeMinutes > 0 || genres.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (runtimeMinutes > 0) '${runtimeMinutes ~/ 60} h ${runtimeMinutes % 60} m',
                      if (genres.isNotEmpty) genres.first,
                    ].join(' • '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
