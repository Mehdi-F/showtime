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
import '../widgets/scrollable_center.dart';
import 'movie_detail_screen.dart';

class _MovieRow {
  final LibraryItem item;
  final MovieDetails details;

  _MovieRow({required this.item, required this.details});
}

class FilmsScreen extends StatefulWidget {
  const FilmsScreen({super.key});

  @override
  State<FilmsScreen> createState() => _FilmsScreenState();
}

class _FilmsScreenState extends State<FilmsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_MovieRow> _resolveRow(TmdbService tmdb, LibraryItem item) async {
    final details = await tmdb.getMovieDetails(item.tmdbId);
    return _MovieRow(item: item, details: details);
  }

  @override
  Widget build(BuildContext context) {
    final movieItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'movie').toList();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Films'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'DÉCOUVRIR'), Tab(text: 'À VOIR'), Tab(text: 'À VENIR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DiscoverMoviesTab(
            key: const ValueKey('discover-dated'),
            followedMovieItems: movieItems,
            tmdb: tmdb,
            sortBy: 'primary_release_date.desc',
            matches: (m) => m.releaseDate != null,
            emptyMessage: 'Aucun film à découvrir pour le moment.',
          ),
          _ToWatchTab(movieItems: movieItems, tmdb: tmdb, resolveRow: _resolveRow),
          _DiscoverMoviesTab(
            key: const ValueKey('discover-undated'),
            followedMovieItems: movieItems,
            tmdb: tmdb,
            sortBy: 'popularity.desc',
            matches: (m) => m.releaseDate == null,
            emptyMessage: 'Aucun film sans date de sortie trouvé.',
          ),
        ],
      ),
    );
  }
}

class _ToWatchTab extends StatefulWidget {
  final List<LibraryItem> movieItems;
  final TmdbService tmdb;
  final Future<_MovieRow> Function(TmdbService, LibraryItem) resolveRow;

  const _ToWatchTab({required this.movieItems, required this.tmdb, required this.resolveRow});

  @override
  State<_ToWatchTab> createState() => _ToWatchTabState();
}

class _ToWatchTabState extends State<_ToWatchTab> {
  static const _pageSize = 21;

  final _scrollController = ScrollController();
  int _visibleCount = _pageSize;
  late Future<List<_MovieRow>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _rowsFuture = _resolveAll();
  }

  @override
  void didUpdateWidget(covariant _ToWatchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the library contents changing should trigger a refetch — the scroll-driven
    // pagination setState below must not recreate this future or the grid will flicker.
    _rowsFuture = _resolveAll();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<_MovieRow>> _resolveAll() =>
      Future.wait(widget.movieItems.map((item) => widget.resolveRow(widget.tmdb, item)));

  Future<void> _refresh() async {
    final future = _resolveAll();
    setState(() => _rowsFuture = future);
    await future;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _refresh, child: _buildBody());
  }

  Widget _buildBody() {
    if (widget.movieItems.isEmpty) {
      return const ScrollableCenter(
        child: Text('Track a movie from Explorer to see it here.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return FutureBuilder<List<_MovieRow>>(
      future: _rowsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ScrollableCenter(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.where((r) => !r.item.watched).toList()
          ..sort((a, b) {
            final dateA = a.details.releaseDate ?? DateTime(0);
            final dateB = b.details.releaseDate ?? DateTime(0);
            return dateB.compareTo(dateA);
          });
        if (rows.isEmpty) {
          return const ScrollableCenter(
              child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)));
        }
        final visible = rows.take(_visibleCount).toList();
        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.67,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final row = visible[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(libraryItem: row.item),
                ));
              },
              child: row.details.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrl}${row.details.posterPath}',
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      alignment: Alignment.center,
                      child: const Icon(Icons.movie, color: AppColors.textSecondary),
                    ),
            );
          },
        );
      },
    );
  }
}

/// Browses TMDB's general movie catalog (not the user's library) for movies
/// that aren't followed yet, matching [matches] (e.g. "has a release date"
/// or "has no release date yet"). Tapping a poster follows it and opens its
/// detail screen.
class _DiscoverMoviesTab extends StatefulWidget {
  final List<LibraryItem> followedMovieItems;
  final TmdbService tmdb;
  final String sortBy;
  final bool Function(SimilarMedia) matches;
  final String emptyMessage;

  const _DiscoverMoviesTab({
    super.key,
    required this.followedMovieItems,
    required this.tmdb,
    required this.sortBy,
    required this.matches,
    required this.emptyMessage,
  });

  @override
  State<_DiscoverMoviesTab> createState() => _DiscoverMoviesTabState();
}

class _DiscoverMoviesTabState extends State<_DiscoverMoviesTab> {
  static const _maxPagesPerLoad = 10;
  static const _minNewItemsPerLoad = 12;
  static const _maxTmdbPage = 500;

  final _scrollController = ScrollController();
  final List<SimilarMedia> _items = [];
  int _nextPage = 1;
  bool _loading = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() => _loading = true);
    var fetchedPages = 0;
    var addedCount = 0;
    while (fetchedPages < _maxPagesPerLoad && addedCount < _minNewItemsPerLoad) {
      if (_nextPage > _maxTmdbPage) {
        _exhausted = true;
        break;
      }
      final results = await widget.tmdb.discoverMovies(page: _nextPage, sortBy: widget.sortBy);
      fetchedPages++;
      if (results.isEmpty) {
        _exhausted = true;
        break;
      }
      _nextPage++;
      final matching = results.where(widget.matches).toList();
      _items.addAll(matching);
      addedCount += matching.length;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _nextPage = 1;
      _exhausted = false;
    });
    await _loadMore();
  }

  Future<void> _follow(SimilarMedia media) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final item = await context.read<LibraryService>().addToLibrary(
          uid: uid,
          tmdbId: media.id,
          type: 'movie',
        );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MovieDetailScreen(libraryItem: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final followedIds = widget.followedMovieItems.map((i) => i.tmdbId).toSet();
    final visible = _items.where((m) => !followedIds.contains(m.id)).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: visible.isEmpty
          ? ScrollableCenter(
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(widget.emptyMessage, style: const TextStyle(color: AppColors.textSecondary)),
            )
          : GridView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.67,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final media = visible[index];
                return GestureDetector(
                  onTap: () => _follow(media),
                  child: media.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: '${TmdbConfig.imageBaseUrl}${media.posterPath}',
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(Icons.movie, color: AppColors.textSecondary),
                        ),
                );
              },
            ),
    );
  }
}
