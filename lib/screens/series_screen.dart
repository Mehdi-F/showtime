import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../logic/up_next.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';
import 'show_detail_screen.dart';

const _staleAfter = Duration(days: 14);

class _UpNextRow {
  final LibraryItem item;
  final String showTitle;
  final String? posterPath;
  final EpisodeRef episode;

  _UpNextRow({
    required this.item,
    required this.showTitle,
    required this.posterPath,
    required this.episode,
  });
}

class _CalendarRow {
  final String showTitle;
  final String? posterPath;
  final NextEpisode episode;

  _CalendarRow({required this.showTitle, required this.posterPath, required this.episode});
}

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> with SingleTickerProviderStateMixin {
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

  Future<_UpNextRow?> _resolveUpNextRow(TmdbService tmdb, LibraryItem item) async {
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
    return _UpNextRow(item: item, showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  Future<_CalendarRow?> _resolveCalendarRow(TmdbService tmdb, int tmdbId) async {
    final details = await tmdb.getTvDetails(tmdbId);
    final next = details.nextEpisodeToAir;
    if (next == null) return null;
    return _CalendarRow(showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séries'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'À VOIR'), Tab(text: 'À VENIR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToWatchTab(tvItems: tvItems, tmdb: tmdb, resolveRow: _resolveUpNextRow),
          _UpcomingTab(tvItems: tvItems, tmdb: tmdb, resolveRow: _resolveCalendarRow),
        ],
      ),
    );
  }
}

class _ToWatchTab extends StatelessWidget {
  final List<LibraryItem> tvItems;
  final TmdbService tmdb;
  final Future<_UpNextRow?> Function(TmdbService, LibraryItem) resolveRow;

  const _ToWatchTab({required this.tvItems, required this.tmdb, required this.resolveRow});

  @override
  Widget build(BuildContext context) {
    if (tvItems.isEmpty) {
      return const Center(
        child: Text('Track a show from Explorer to see it here.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return FutureBuilder<List<_UpNextRow?>>(
      future: Future.wait(tvItems.map((item) => resolveRow(tmdb, item))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.whereType<_UpNextRow>().toList();
        if (rows.isEmpty) {
          return const Center(child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)));
        }
        final now = DateTime.now();
        final active = <_UpNextRow>[];
        final stale = <_UpNextRow>[];
        for (final row in rows) {
          final lastActivity = row.item.lastActivityAt;
          if (lastActivity == null || now.difference(lastActivity) > _staleAfter) {
            stale.add(row);
          } else {
            active.add(row);
          }
        }
        return ListView(
          children: [
            if (active.isNotEmpty) ..._section(context, 'À VOIR', active),
            if (stale.isNotEmpty) ..._section(context, 'PAS REGARDÉ DEPUIS UN MOMENT', stale),
          ],
        );
      },
    );
  }

  List<Widget> _section(BuildContext context, String label, List<_UpNextRow> rows) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
      ...rows.map((row) => MediaListTile(
            posterPath: row.posterPath,
            title: row.showTitle,
            subtitle: 'S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ShowDetailScreen(libraryItem: row.item),
              ));
            },
          )),
    ];
  }
}

class _UpcomingTab extends StatelessWidget {
  final List<LibraryItem> tvItems;
  final TmdbService tmdb;
  final Future<_CalendarRow?> Function(TmdbService, int) resolveRow;

  const _UpcomingTab({required this.tvItems, required this.tmdb, required this.resolveRow});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    if (tvItems.isEmpty) {
      return const Center(
        child: Text('Track a show from Explorer to see upcoming episodes.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return FutureBuilder<List<_CalendarRow?>>(
      future: Future.wait(tvItems.map((item) => resolveRow(tmdb, item.tmdbId))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!.whereType<_CalendarRow>().toList()
          ..sort((a, b) {
            final aDate = a.episode.airDate;
            final bDate = b.episode.airDate;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
        if (rows.isEmpty) {
          return const Center(
              child: Text('No upcoming episodes scheduled.', style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final date = row.episode.airDate;
            return MediaListTile(
              posterPath: row.posterPath,
              title: row.showTitle,
              subtitle: 'S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}',
              trailing: Text(
                date != null ? dateFormat.format(date) : 'TBA',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }
}
