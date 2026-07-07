import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tmdb_config.dart';
import '../logic/up_next.dart';
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
import 'show_detail_screen.dart';

enum _ViewMode { list, grid }

enum _SeriesFilter { all, inProgress, notStarted, upToDate, completed, cancelled, favorites }

extension on _SeriesFilter {
  String get label => switch (this) {
        _SeriesFilter.all => 'Tout',
        _SeriesFilter.inProgress => 'Vos séries en cours',
        _SeriesFilter.notStarted => "N'a pas encore commencé",
        _SeriesFilter.upToDate => 'À jour',
        _SeriesFilter.completed => 'Terminé',
        _SeriesFilter.cancelled => 'Arrêtées',
        _SeriesFilter.favorites => 'Favoris',
      };
}

const _frMonthsShort = [
  'JANV.',
  'FÉVR.',
  'MARS',
  'AVR.',
  'MAI',
  'JUIN',
  'JUIL.',
  'AOÛT',
  'SEPT.',
  'OCT.',
  'NOV.',
  'DÉC.'
];
const _frWeekdays = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'];

/// Runs `action` over `items` with at most `concurrency` in flight at once.
Future<void> _forEachBounded<T>(List<T> items, int concurrency, Future<void> Function(T item) action) async {
  var index = 0;
  Future<void> worker() async {
    while (true) {
      final current = index;
      if (current >= items.length) return;
      index++;
      await action(items[current]);
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
}

int _daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

String _dayGroupLabel(DateTime date) {
  final diff = _daysUntil(date);
  if (diff == 0) return "AUJOURD'HUI";
  if (diff == -1) return 'HIER';
  if (diff == 1) return 'DEMAIN';
  if (diff > 1 && diff <= 6) return _frWeekdays[date.weekday - 1];
  return '${date.day} ${_frMonthsShort[date.month - 1]}';
}

class _ShowEpisodesData {
  final LibraryItem item;
  final String showTitle;
  final String? posterPath;
  final EpisodeRef? nextEpisode;
  final int extraUnwatched;
  final int totalEpisodeCount;
  final bool isEnded;
  final String status; // raw TMDB status, used to tell Ended apart from Canceled
  final List<EpisodeRef> allEpisodes;

  _ShowEpisodesData({
    required this.item,
    required this.showTitle,
    required this.posterPath,
    required this.nextEpisode,
    required this.extraUnwatched,
    required this.totalEpisodeCount,
    required this.isEnded,
    required this.status,
    required this.allEpisodes,
  });

  int get watchedEpisodesCount => item.watchedEpisodes.values.where((w) => w).length;
}

/// Categorizes a show for the progress filter. Cancelled takes priority over
/// watch progress (there will never be more episodes), then completion,
/// then whether anything at all has been watched.
_SeriesFilter _categorize(_ShowEpisodesData d) {
  if (d.status == 'Canceled') return _SeriesFilter.cancelled;
  final total = d.totalEpisodeCount;
  final watched = d.watchedEpisodesCount;
  if (total > 0 && watched >= total) {
    return d.isEnded ? _SeriesFilter.completed : _SeriesFilter.upToDate;
  }
  if (watched == 0) return _SeriesFilter.notStarted;
  return _SeriesFilter.inProgress;
}

class _ProgressInfo {
  final double ratio;
  final Color color;

  _ProgressInfo(this.ratio, this.color);
}

_ProgressInfo? _progressInfo(_ShowEpisodesData d) {
  if (d.totalEpisodeCount <= 0) return null;
  final ratio = d.watchedEpisodesCount / d.totalEpisodeCount;
  if (ratio >= 1.0) return _ProgressInfo(1.0, d.isEnded ? Colors.purple : Colors.green);
  return _ProgressInfo(ratio, AppColors.accent);
}

class _CalendarRow {
  final LibraryItem item;
  final String showTitle;
  final String? posterPath;
  final NextEpisode episode;

  _CalendarRow({required this.item, required this.showTitle, required this.posterPath, required this.episode});
}

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> with SingleTickerProviderStateMixin {
  static const _prefsKey = 'series_view_mode';
  late final TabController _tabController;
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (mounted && saved == _ViewMode.grid.name) {
      setState(() => _viewMode = _ViewMode.grid);
    }
  }

  Future<void> _toggleViewMode() async {
    final newMode = _viewMode == _ViewMode.list ? _ViewMode.grid : _ViewMode.list;
    setState(() => _viewMode = newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newMode.name);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_ShowEpisodesData> _resolveShowEpisodes(TmdbService tmdb, LibraryItem item) async {
    final details = await tmdb.getTvDetails(item.tmdbId);
    final episodesBySeason = List<List<EpisodeRef>?>.filled(details.seasons.length, null);
    await _forEachBounded(List.generate(details.seasons.length, (i) => i), 4, (i) async {
      final seasonDetails = await tmdb.getSeasonDetails(item.tmdbId, details.seasons[i].seasonNumber);
      episodesBySeason[i] = seasonDetails.episodes;
    });
    final allEpisodes = <EpisodeRef>[for (final episodes in episodesBySeason) ...episodes!];
    final now = DateTime.now();
    final next = nextUnwatchedEpisode(episodesInOrder: allEpisodes, watchedEpisodes: item.watchedEpisodes, now: now);
    final unwatchedCount = allEpisodes.where((e) {
      if (item.watchedEpisodes[e.key] == true) return false;
      if (e.airDate != null && e.airDate!.isAfter(now)) return false;
      return true;
    }).length;
    return _ShowEpisodesData(
      item: item,
      showTitle: details.name,
      posterPath: details.posterPath,
      nextEpisode: next,
      extraUnwatched: next == null ? 0 : unwatchedCount - 1,
      totalEpisodeCount: allEpisodes.length,
      isEnded: details.isEnded,
      status: details.status,
      allEpisodes: allEpisodes,
    );
  }

  Future<_CalendarRow?> _resolveCalendarRow(TmdbService tmdb, LibraryItem item) async {
    final details = await tmdb.getTvDetails(item.tmdbId);
    final next = details.nextEpisodeToAir;
    if (next == null) return null;
    return _CalendarRow(item: item, showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'SÉRIES'), Tab(text: 'À VENIR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToWatchTab(
            tvItems: tvItems,
            tmdb: tmdb,
            resolveRow: _resolveShowEpisodes,
            viewMode: _viewMode,
            onToggleViewMode: _toggleViewMode,
          ),
          _UpcomingTab(
            tvItems: tvItems,
            tmdb: tmdb,
            resolveRow: _resolveCalendarRow,
            viewMode: _viewMode,
            onToggleViewMode: _toggleViewMode,
          ),
        ],
      ),
    );
  }
}

class _ToWatchTab extends StatefulWidget {
  final List<LibraryItem> tvItems;
  final TmdbService tmdb;
  final Future<_ShowEpisodesData> Function(TmdbService, LibraryItem) resolveRow;
  final _ViewMode viewMode;
  final VoidCallback onToggleViewMode;

  const _ToWatchTab({
    required this.tvItems,
    required this.tmdb,
    required this.resolveRow,
    required this.viewMode,
    required this.onToggleViewMode,
  });

  @override
  State<_ToWatchTab> createState() => _ToWatchTabState();
}

class _ToWatchTabState extends State<_ToWatchTab> {
  late Future<List<_ShowEpisodesData>> _dataFuture;
  final _scrollController = ScrollController();
  LibrarySort _sort = LibrarySort.lastActivity;
  _SeriesFilter _filter = _SeriesFilter.all;

  @override
  void initState() {
    super.initState();
    _dataFuture = _resolveAll();
  }

  @override
  void didUpdateWidget(covariant _ToWatchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _dataFuture = _resolveAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<_ShowEpisodesData>> _resolveAll() async {
    final results = List<_ShowEpisodesData?>.filled(widget.tvItems.length, null);
    await _forEachBounded(List.generate(widget.tvItems.length, (i) => i), 5, (i) async {
      try {
        results[i] = await widget.resolveRow(widget.tmdb, widget.tvItems[i]);
      } catch (_) {
        // A single show failing to load (TMDB hiccup, rate limit) shouldn't
        // block the rest of the list from rendering.
      }
    });
    return results.whereType<_ShowEpisodesData>().toList();
  }

  Future<void> _refresh() async {
    widget.tmdb.clearCache();
    final future = _resolveAll();
    setState(() => _dataFuture = future);
    await future;
  }

  Future<void> _openFilterSheet() async {
    final result = await showLibraryFilterSheet<_SeriesFilter>(
      context,
      initialSort: _sort,
      progressTitle: 'Progress',
      filterValues: _SeriesFilter.values,
      filterLabel: (f) => f.label,
      initialFilter: _filter,
      defaultFilter: _SeriesFilter.all,
    );
    if (result != null && mounted) {
      setState(() {
        _sort = result.sort;
        _filter = result.filter;
      });
    }
  }

  bool _matchesFilter(_ShowEpisodesData d) {
    switch (_filter) {
      case _SeriesFilter.all:
        return true;
      case _SeriesFilter.favorites:
        return d.item.favorite;
      case _SeriesFilter.inProgress:
      case _SeriesFilter.notStarted:
      case _SeriesFilter.upToDate:
      case _SeriesFilter.completed:
      case _SeriesFilter.cancelled:
        return _categorize(d) == _filter;
    }
  }

  List<_ShowEpisodesData> _applyFilterAndSort(List<_ShowEpisodesData> data) {
    final filtered = data.where(_matchesFilter).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case LibrarySort.lastActivity:
          final da = a.item.lastActivityAt ?? a.item.addedAt;
          final db = b.item.lastActivityAt ?? b.item.addedAt;
          return db.compareTo(da);
        case LibrarySort.lastAdded:
          return b.item.addedAt.compareTo(a.item.addedAt);
        case LibrarySort.alphabetical:
          return a.showTitle.toLowerCase().compareTo(b.showTitle.toLowerCase());
      }
    });
    return filtered;
  }

  Future<void> _toggleAllEpisodes(BuildContext context, _ShowEpisodesData d, bool newValue) {
    final uid = context.read<AuthProvider>().user!.uid;
    final keys = d.allEpisodes.map((e) => e.key).toList();
    return context.read<LibraryService>().setEpisodesWatched(
          uid: uid,
          tmdbId: d.item.tmdbId,
          episodeKeys: keys,
          watched: newValue,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: RefreshIndicator(onRefresh: _refresh, child: _buildBody(context))),
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

  Widget _buildBody(BuildContext context) {
    if (widget.tvItems.isEmpty) {
      return const ScrollableCenter(
        child: Text('Track a show from Explorer to see it here.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return FutureBuilder<List<_ShowEpisodesData>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ScrollableCenter(child: CircularProgressIndicator());
        }
        final visible = _applyFilterAndSort(snapshot.data!);
        return Column(
          children: [
            LibraryFilterBadge(label: _filter.label, onTap: _openFilterSheet),
            if (visible.isEmpty)
              const Expanded(
                child: ScrollableCenter(
                  child: Text('Aucune série ne correspond à ce filtre.',
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

  Widget _buildGrid(List<_ShowEpisodesData> visible) {
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
        final d = visible[index];
        final info = _progressInfo(d);
        return _SeriesProgressCard(
          posterPath: d.posterPath,
          progress: info?.ratio,
          barColor: info?.color,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: d.item))),
        );
      },
    );
  }

  Widget _buildList(List<_ShowEpisodesData> visible) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final d = visible[index];
        final total = d.totalEpisodeCount;
        final watched = d.watchedEpisodesCount;
        final fullyWatched = total > 0 && watched >= total;
        return InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: d.item))),
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
                    child: d.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: '${TmdbConfig.imageBaseUrl}${d.posterPath}',
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.tv, color: AppColors.textSecondary),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.showTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (total > 0) ...[
                        const SizedBox(height: 4),
                        Text('$watched/$total épisodes',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RoundCheck(
                  checked: fullyWatched,
                  onTap: () => _toggleAllEpisodes(context, d, !fullyWatched),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UpcomingTab extends StatefulWidget {
  final List<LibraryItem> tvItems;
  final TmdbService tmdb;
  final Future<_CalendarRow?> Function(TmdbService, LibraryItem) resolveRow;
  final _ViewMode viewMode;
  final VoidCallback onToggleViewMode;

  const _UpcomingTab({
    required this.tvItems,
    required this.tmdb,
    required this.resolveRow,
    required this.viewMode,
    required this.onToggleViewMode,
  });

  @override
  State<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<_UpcomingTab> {
  late Future<List<_CalendarRow?>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _resolveAll();
  }

  @override
  void didUpdateWidget(covariant _UpcomingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rowsFuture = _resolveAll();
  }

  Future<List<_CalendarRow?>> _resolveAll() async {
    final results = List<_CalendarRow?>.filled(widget.tvItems.length, null);
    await _forEachBounded(List.generate(widget.tvItems.length, (i) => i), 8, (i) async {
      try {
        results[i] = await widget.resolveRow(widget.tmdb, widget.tvItems[i]);
      } catch (_) {
        // A single show failing to load shouldn't block the rest of the list.
      }
    });
    return results;
  }

  Future<void> _refresh() async {
    widget.tmdb.clearCache();
    final future = _resolveAll();
    setState(() => _rowsFuture = future);
    await future;
  }

  Future<void> _toggleEpisode(BuildContext context, LibraryItem item, int season, int episode, bool newValue) {
    final uid = context.read<AuthProvider>().user!.uid;
    return context.read<LibraryService>().markEpisodeWatched(
          uid: uid,
          tmdbId: item.tmdbId,
          season: season,
          episode: episode,
          watched: newValue,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: RefreshIndicator(onRefresh: _refresh, child: _buildBody(context))),
        Positioned(
          top: 12,
          right: 16,
          child: ViewModeToggle(isGrid: widget.viewMode == _ViewMode.grid, onTap: widget.onToggleViewMode),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.tvItems.isEmpty) {
      return const ScrollableCenter(
        child: Text('Track a show from Explorer to see upcoming episodes.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return FutureBuilder<List<_CalendarRow?>>(
      future: _rowsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ScrollableCenter(child: CircularProgressIndicator());
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
          return const ScrollableCenter(
              child: Text('No upcoming episodes scheduled.', style: TextStyle(color: AppColors.textSecondary)));
        }

        final now = DateTime.now();
        final groups = <String, List<_CalendarRow>>{};
        for (final row in rows) {
          final date = row.episode.airDate;
          final label = date != null ? _dayGroupLabel(date) : 'DATE INCONNUE';
          groups.putIfAbsent(label, () => []).add(row);
        }

        final children = <Widget>[];
        groups.forEach((label, groupRows) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ));
          if (widget.viewMode == _ViewMode.list) {
            for (final row in groupRows) {
              final date = row.episode.airDate;
              final badges = <String>['NOUVEAU'];
              if (row.episode.episodeNumber == 1) badges.add('PREMIERE');
              final aired = date != null && date.isBefore(now);
              if (aired) badges.add('DIFFUSÉ');
              final watched = row.item.watchedEpisodes[row.episode.key] ?? false;
              children.add(_EpisodeCard(
                posterPath: row.posterPath,
                showTitle: row.showTitle,
                seasonNumber: row.episode.seasonNumber,
                episodeNumber: row.episode.episodeNumber,
                episodeTitle: row.episode.name,
                badgeLabels: badges,
                watched: watched,
                onToggleWatched: () => _toggleEpisode(
                    context, row.item, row.episode.seasonNumber, row.episode.episodeNumber, !watched),
                onTapShow: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: row.item))),
              ));
            }
          } else {
            children.add(GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.67,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: groupRows.length,
              itemBuilder: (context, index) {
                final row = groupRows[index];
                final date = row.episode.airDate;
                return _SeriesProgressCard(
                  posterPath: row.posterPath,
                  daysUntil: date != null ? _daysUntil(date) : null,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: row.item))),
                );
              },
            ));
          }
        });

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: children,
        );
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final String? posterPath;
  final String showTitle;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeTitle;
  final int? extraCount;
  final List<String> badgeLabels;
  final bool watched;
  final bool dimmed;
  final VoidCallback onToggleWatched;
  final VoidCallback onTapShow;

  const _EpisodeCard({
    required this.posterPath,
    required this.showTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    this.extraCount,
    this.badgeLabels = const [],
    required this.watched,
    this.dimmed = false,
    required this.onToggleWatched,
    required this.onTapShow,
  });

  Widget _buildBadge(String label) {
    Color? fill;
    var textColor = Colors.white;
    switch (label) {
      case 'NOUVEAU':
        fill = AppColors.accent;
        textColor = Colors.black;
        break;
      case 'DIFFUSÉ':
        fill = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        border: fill == null ? Border.all(color: Colors.white38) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = dimmed ? AppColors.textSecondary : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 70,
              height: 100,
              child: posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.tv, color: AppColors.textSecondary),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTapShow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            showTitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'S${seasonNumber.toString().padLeft(2, '0')} | E${episodeNumber.toString().padLeft(2, '0')}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: titleColor),
                    ),
                    if (extraCount != null && extraCount! > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('+$extraCount',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  episodeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: titleColor),
                ),
                if (badgeLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: badgeLabels.map(_buildBadge).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RoundCheck(checked: watched, onTap: onToggleWatched),
        ],
      ),
    );
  }
}

class _SeriesProgressCard extends StatelessWidget {
  final String? posterPath;
  final VoidCallback onTap;
  final double? progress;
  final Color? barColor;
  final int? daysUntil;

  const _SeriesProgressCard({
    required this.posterPath,
    required this.onTap,
    this.progress,
    this.barColor,
    this.daysUntil,
  });

  Widget? _buildDayBadge() {
    final days = daysUntil;
    if (days == null || days == 0) return null;
    if (days < 0) {
      return const Text('HIER',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$days',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, height: 1)),
        Text(days == 1 ? 'JOUR' : 'JOURS',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayBadge = _buildDayBadge();
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: posterPath != null
                ? CachedNetworkImage(
                    imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.tv, color: AppColors.textSecondary),
                  ),
          ),
          if (dayBadge != null)
            Positioned(
              left: 6,
              bottom: progress != null ? 12 : 6,
              child: dayBadge,
            ),
          if (progress != null && barColor != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 6,
                color: Colors.black45,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress!.clamp(0.0, 1.0).toDouble(),
                  child: Container(color: barColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
