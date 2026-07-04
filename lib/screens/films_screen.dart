import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [Tab(text: 'À VOIR'), Tab(text: 'À VENIR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToWatchTab(movieItems: movieItems, tmdb: tmdb, resolveRow: _resolveRow),
          _UpcomingTab(movieItems: movieItems, tmdb: tmdb, resolveRow: _resolveRow),
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

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movieItems.isEmpty) {
      return const Center(
          child: Text('Track a movie from Explorer to see it here.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return FutureBuilder<List<_MovieRow>>(
      future: _rowsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.where((r) => !r.item.watched).toList()
          ..sort((a, b) {
            final dateA = a.details.releaseDate ?? DateTime(0);
            final dateB = b.details.releaseDate ?? DateTime(0);
            return dateB.compareTo(dateA);
          });
        if (rows.isEmpty) {
          return const Center(child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)));
        }
        final visible = rows.take(_visibleCount).toList();
        return GridView.builder(
          controller: _scrollController,
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

class _UpcomingTab extends StatelessWidget {
  final List<LibraryItem> movieItems;
  final TmdbService tmdb;
  final Future<_MovieRow> Function(TmdbService, LibraryItem) resolveRow;

  const _UpcomingTab({required this.movieItems, required this.tmdb, required this.resolveRow});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    if (movieItems.isEmpty) {
      return const Center(
          child: Text('Track a movie from Explorer to see upcoming releases.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return FutureBuilder<List<_MovieRow>>(
      future: Future.wait(movieItems.map((item) => resolveRow(tmdb, item))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final rows = snapshot.data!.where((r) => r.details.releaseDate?.isAfter(now) ?? false).toList()
          ..sort((a, b) => a.details.releaseDate!.compareTo(b.details.releaseDate!));
        if (rows.isEmpty) {
          return const Center(
              child: Text('No upcoming releases tracked.', style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return MediaListTile(
              posterPath: row.details.posterPath,
              title: row.details.title,
              trailing: Text(
                dateFormat.format(row.details.releaseDate!),
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(libraryItem: row.item),
                ));
              },
            );
          },
        );
      },
    );
  }
}
