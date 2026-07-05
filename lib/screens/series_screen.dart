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
import '../widgets/round_check.dart';
import '../widgets/scrollable_center.dart';
import 'show_detail_screen.dart';

enum _ViewMode { list, grid }

const _staleAfter = Duration(days: 14);
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
  final List<EpisodeRef> allEpisodes;

  _ShowEpisodesData({
    required this.item,
    required this.showTitle,
    required this.posterPath,
    required this.nextEpisode,
    required this.extraUnwatched,
    required this.totalEpisodeCount,
    required this.isEnded,
    required this.allEpisodes,
  });

  int get watchedEpisodesCount => item.watchedEpisodes.values.where((w) => w).length;
}

class _HistoryEntry {
  final _ShowEpisodesData show;
  final EpisodeRef episode;
  final DateTime watchedAt;

  _HistoryEntry({required this.show, required this.episode, required this.watchedAt});
}

/// Flattens every show's individually-timestamped watched episodes into one
/// chronological list (oldest first), most recent 200 kept.
List<_HistoryEntry> _buildHistory(List<_ShowEpisodesData> data) {
  final entries = <_HistoryEntry>[];
  for (final d in data) {
    for (final ep in d.allEpisodes) {
      final watchedAt = d.item.episodeWatchedAt[ep.key];
      if (watchedAt != null) {
        entries.add(_HistoryEntry(show: d, episode: ep, watchedAt: watchedAt));
      }
    }
  }
  entries.sort((a, b) => a.watchedAt.compareTo(b.watchedAt));
  if (entries.length > 200) {
    return entries.sublist(entries.length - 200);
  }
  return entries;
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
    final allEpisodes = <EpisodeRef>[];
    for (final season in details.seasons) {
      final seasonDetails = await tmdb.getSeasonDetails(item.tmdbId, season.seasonNumber);
      allEpisodes.addAll(seasonDetails.episodes);
    }
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
        title: const Text('Séries'),
        actions: [
          IconButton(
            icon: Icon(_viewMode == _ViewMode.list ? Icons.grid_view : Icons.view_list),
            tooltip: 'Changer la vue',
            onPressed: _toggleViewMode,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'À VOIR'), Tab(text: 'À VENIR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToWatchTab(tvItems: tvItems, tmdb: tmdb, resolveRow: _resolveShowEpisodes, viewMode: _viewMode),
          _UpcomingTab(tvItems: tvItems, tmdb: tmdb, resolveRow: _resolveCalendarRow, viewMode: _viewMode),
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

  const _ToWatchTab({
    required this.tvItems,
    required this.tmdb,
    required this.resolveRow,
    required this.viewMode,
  });

  @override
  State<_ToWatchTab> createState() => _ToWatchTabState();
}

class _ToWatchTabState extends State<_ToWatchTab> {
  late Future<List<_ShowEpisodesData>> _dataFuture;

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

  Future<List<_ShowEpisodesData>> _resolveAll() =>
      Future.wait(widget.tvItems.map((item) => widget.resolveRow(widget.tmdb, item)));

  Future<void> _refresh() async {
    final future = _resolveAll();
    setState(() => _dataFuture = future);
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
    return RefreshIndicator(onRefresh: _refresh, child: _buildBody(context));
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
        final data = snapshot.data!;
        final now = DateTime.now();

        final history = _buildHistory(data);

        final withNext = data.where((d) => d.nextEpisode != null).toList();
        final active = <_ShowEpisodesData>[];
        final stale = <_ShowEpisodesData>[];
        for (final d in withNext) {
          final lastActivity = d.item.lastActivityAt;
          if (lastActivity == null || now.difference(lastActivity) > _staleAfter) {
            stale.add(d);
          } else {
            active.add(d);
          }
        }
        active.sort((a, b) {
          final aDate = a.nextEpisode!.airDate;
          final bDate = b.nextEpisode!.airDate;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        if (history.isEmpty && active.isEmpty && stale.isEmpty) {
          return const ScrollableCenter(
              child: Text('All caught up.', style: TextStyle(color: AppColors.textSecondary)));
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: widget.viewMode == _ViewMode.list
              ? [
                  if (history.isNotEmpty) ..._historySection(context, history),
                  if (active.isNotEmpty) ..._activeSection(context, active),
                  if (stale.isNotEmpty) ..._staleSection(context, stale),
                ]
              : [
                  if (active.isNotEmpty) _buildCardSection(context, 'À VOIR', active),
                  if (stale.isNotEmpty) _buildCardSection(context, 'PAS REGARDÉ DEPUIS UN MOMENT', stale),
                ],
        );
      },
    );
  }

  Widget _buildCardSection(BuildContext context, String label, List<_ShowEpisodesData> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(label),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.67,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final d = rows[index];
            final info = _progressInfo(d);
            return _SeriesProgressCard(
              posterPath: d.posterPath,
              progress: info?.ratio,
              barColor: info?.color,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: d.item))),
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  List<Widget> _historySection(BuildContext context, List<_HistoryEntry> entries) {
    return [
      _sectionHeader('HISTORIQUE DE VISIONNAGE'),
      ...entries.map((h) {
        final ep = h.episode;
        final d = h.show;
        return Opacity(
          opacity: 0.6,
          child: _EpisodeCard(
            posterPath: d.posterPath,
            showTitle: d.showTitle,
            seasonNumber: ep.seasonNumber,
            episodeNumber: ep.episodeNumber,
            episodeTitle: ep.name,
            watched: true,
            dimmed: true,
            onToggleWatched: () => _toggleEpisode(context, d.item, ep.seasonNumber, ep.episodeNumber, false),
            onTapShow: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: d.item))),
          ),
        );
      }),
    ];
  }

  List<Widget> _activeSection(BuildContext context, List<_ShowEpisodesData> rows) {
    return [
      _sectionHeader('À VOIR'),
      for (var i = 0; i < rows.length; i++)
        _buildNextCard(context, rows[i], showMostRecentBadge: i == 0 && rows[i].nextEpisode!.airDate != null),
    ];
  }

  List<Widget> _staleSection(BuildContext context, List<_ShowEpisodesData> rows) {
    return [
      _sectionHeader('PAS REGARDÉ DEPUIS UN MOMENT'),
      for (final d in rows) _buildNextCard(context, d, showMostRecentBadge: false),
    ];
  }

  Widget _buildNextCard(BuildContext context, _ShowEpisodesData d, {required bool showMostRecentBadge}) {
    final ep = d.nextEpisode!;
    return _EpisodeCard(
      posterPath: d.posterPath,
      showTitle: d.showTitle,
      seasonNumber: ep.seasonNumber,
      episodeNumber: ep.episodeNumber,
      episodeTitle: ep.name,
      extraCount: d.extraUnwatched > 0 ? d.extraUnwatched : null,
      watched: false,
      badgeLabels: showMostRecentBadge ? const ['PLUS RÉCENT'] : const [],
      onToggleWatched: () => _toggleEpisode(context, d.item, ep.seasonNumber, ep.episodeNumber, true),
      onTapShow: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShowDetailScreen(libraryItem: d.item))),
    );
  }
}

class _UpcomingTab extends StatefulWidget {
  final List<LibraryItem> tvItems;
  final TmdbService tmdb;
  final Future<_CalendarRow?> Function(TmdbService, LibraryItem) resolveRow;
  final _ViewMode viewMode;

  const _UpcomingTab({
    required this.tvItems,
    required this.tmdb,
    required this.resolveRow,
    required this.viewMode,
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

  Future<List<_CalendarRow?>> _resolveAll() =>
      Future.wait(widget.tvItems.map((item) => widget.resolveRow(widget.tmdb, item)));

  Future<void> _refresh() async {
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
    return RefreshIndicator(onRefresh: _refresh, child: _buildBody(context));
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
