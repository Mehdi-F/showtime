import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

class _ToWatchTab extends StatelessWidget {
  final List<LibraryItem> movieItems;
  final TmdbService tmdb;
  final Future<_MovieRow> Function(TmdbService, LibraryItem) resolveRow;

  const _ToWatchTab({required this.movieItems, required this.tmdb, required this.resolveRow});

  @override
  Widget build(BuildContext context) {
    if (movieItems.isEmpty) {
      return const Center(
          child: Text('Track a movie from Explorer to see it here.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return FutureBuilder<List<_MovieRow>>(
      future: Future.wait(movieItems.map((item) => resolveRow(tmdb, item))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.where((r) => !r.item.watched).toList();
        if (rows.isEmpty) {
          return const Center(child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return MediaListTile(
              posterPath: row.details.posterPath,
              title: row.details.title,
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
