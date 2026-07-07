import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/library_filter_sheet.dart';
import '../widgets/round_check.dart';
import '../widgets/scrollable_center.dart';
import '../widgets/view_mode_toggle.dart';
import 'movie_detail_screen.dart';

enum _ViewMode { grid, list }

enum _FilmFilter { all, watched, unwatched, favorites }

extension on _FilmFilter {
  String get label => switch (this) {
        _FilmFilter.all => 'Tous',
        _FilmFilter.watched => 'Vu',
        _FilmFilter.unwatched => 'Non vu',
        _FilmFilter.favorites => 'Favoris',
      };
}

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

class _FilmsScreenState extends State<FilmsScreen> {
  static const _prefsKey = 'films_view_mode';
  _ViewMode _viewMode = _ViewMode.grid;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (mounted && saved == _ViewMode.list.name) {
      setState(() => _viewMode = _ViewMode.list);
    }
  }

  Future<void> _toggleViewMode() async {
    final newMode = _viewMode == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid;
    setState(() => _viewMode = newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newMode.name);
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
      body: SafeArea(
        child: _ToWatchTab(
          movieItems: movieItems,
          tmdb: tmdb,
          resolveRow: _resolveRow,
          viewMode: _viewMode,
          onToggleViewMode: _toggleViewMode,
        ),
      ),
    );
  }
}

class _ToWatchTab extends StatefulWidget {
  final List<LibraryItem> movieItems;
  final TmdbService tmdb;
  final Future<_MovieRow> Function(TmdbService, LibraryItem) resolveRow;
  final _ViewMode viewMode;
  final VoidCallback onToggleViewMode;

  const _ToWatchTab({
    required this.movieItems,
    required this.tmdb,
    required this.resolveRow,
    required this.viewMode,
    required this.onToggleViewMode,
  });

  @override
  State<_ToWatchTab> createState() => _ToWatchTabState();
}

class _ToWatchTabState extends State<_ToWatchTab> {
  static const _pageSize = 21;

  final _scrollController = ScrollController();
  int _visibleCount = _pageSize;
  late Future<List<_MovieRow>> _rowsFuture;
  LibrarySort _sort = LibrarySort.lastActivity;
  _FilmFilter _filter = _FilmFilter.all;

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

  Future<List<_MovieRow>> _resolveAll() async {
    final rows = await Future.wait(widget.movieItems.map((item) async {
      try {
        return await widget.resolveRow(widget.tmdb, item);
      } catch (_) {
        // A single movie failing to load (TMDB hiccup) shouldn't block the
        // rest of the list from rendering.
        return null;
      }
    }));
    return rows.whereType<_MovieRow>().toList();
  }

  Future<void> _refresh() async {
    widget.tmdb.clearCache();
    final future = _resolveAll();
    setState(() => _rowsFuture = future);
    await future;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  Future<void> _toggleWatched(LibraryItem item, bool newValue) {
    final uid = context.read<AuthProvider>().user!.uid;
    return context.read<LibraryService>().markMovieWatched(
          uid: uid,
          tmdbId: item.tmdbId,
          watched: newValue,
        );
  }

  Future<void> _openFilterSheet() async {
    final result = await showLibraryFilterSheet<_FilmFilter>(
      context,
      initialSort: _sort,
      progressTitle: 'Avancement',
      filterValues: _FilmFilter.values,
      filterLabel: (f) => f.label,
      initialFilter: _filter,
      defaultFilter: _FilmFilter.all,
    );
    if (result != null && mounted) {
      setState(() {
        _sort = result.sort;
        _filter = result.filter;
      });
    }
  }

  List<_MovieRow> _applyFilterAndSort(List<_MovieRow> rows) {
    final filtered = rows.where((r) {
      switch (_filter) {
        case _FilmFilter.all:
          return true;
        case _FilmFilter.watched:
          return r.item.watched;
        case _FilmFilter.unwatched:
          return !r.item.watched;
        case _FilmFilter.favorites:
          return r.item.favorite;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case LibrarySort.lastActivity:
          final dateA = a.item.watchedAt ?? a.item.addedAt;
          final dateB = b.item.watchedAt ?? b.item.addedAt;
          return dateB.compareTo(dateA);
        case LibrarySort.lastAdded:
          return b.item.addedAt.compareTo(a.item.addedAt);
        case LibrarySort.alphabetical:
          return a.details.title.toLowerCase().compareTo(b.details.title.toLowerCase());
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: RefreshIndicator(onRefresh: _refresh, child: _buildBody())),
        Positioned(
          top: 12,
          right: 16,
          child: ViewModeToggle(isGrid: widget.viewMode == _ViewMode.grid, onTap: widget.onToggleViewMode),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(child: LibraryFilterButton(onTap: _openFilterSheet)),
        ),
      ],
    );
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
        final visible = _applyFilterAndSort(snapshot.data!).take(_visibleCount).toList();
        return Column(
          children: [
            LibraryFilterBadge(label: _filter.label, onTap: _openFilterSheet),
            if (visible.isEmpty)
              const Expanded(
                child: ScrollableCenter(
                  child: Text('Aucun film ne correspond à ce filtre.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              Expanded(child: widget.viewMode == _ViewMode.grid ? _buildGrid(visible) : _buildList(visible)),
          ],
        );
      },
    );
  }

  Widget _buildGrid(List<_MovieRow> visible) {
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              row.details.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrl}${row.details.posterPath}',
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      alignment: Alignment.center,
                      child: const Icon(Icons.movie, color: AppColors.textSecondary),
                    ),
              if (row.item.watched)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 4, color: Colors.green),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<_MovieRow> visible) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final row = visible[index];
        final parts = <String>[
          if (row.details.runtime > 0) '${row.details.runtime ~/ 60} h ${row.details.runtime % 60} m',
          if (row.details.genres.isNotEmpty) row.details.genres.join(', '),
        ];
        return InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MovieDetailScreen(libraryItem: row.item),
            ));
          },
          child: Container(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 56,
                    height: 78,
                    child: row.details.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: '${TmdbConfig.imageBaseUrl}${row.details.posterPath}',
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.movie, color: AppColors.textSecondary),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(row.details.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (parts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(parts.join(' • '),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RoundCheck(
                  checked: row.item.watched,
                  onTap: () => _toggleWatched(row.item, !row.item.watched),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
