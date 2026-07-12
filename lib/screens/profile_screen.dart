import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/watch_list.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/lists_provider.dart';
import '../services/library_service.dart';
import '../services/lists_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/app_page_route.dart';
import '../widgets/fade_in_entry.dart';
import '../widgets/library_filter_sheet.dart';
import '../widgets/poster_hero_tag.dart';
import '../widgets/scrollable_center.dart';
import '../widgets/skeletons.dart';
import 'friends_screen.dart';
import 'import_tvtime_screen.dart';
import 'list_detail_screen.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

Future<_ResolvedItem> _resolveItem(TmdbService tmdb, LibraryItem item) async {
  if (item.type == 'tv') {
    final details = await tmdb.getTvDetails(item.tmdbId);
    final totalEpisodeCount = details.seasons.fold<int>(0, (sum, s) => sum + s.episodeCount);
    return _ResolvedItem(
      item: item,
      title: details.name,
      posterPath: details.posterPath,
      backdropPath: details.backdropPath,
      runtimeMinutes: details.episodeRunTime,
      totalEpisodeCount: totalEpisodeCount,
      isEnded: details.isEnded,
      status: details.status,
    );
  } else {
    final details = await tmdb.getMovieDetails(item.tmdbId);
    return _ResolvedItem(
      item: item,
      title: details.title,
      posterPath: details.posterPath,
      backdropPath: details.backdropPath,
      runtimeMinutes: details.runtime,
    );
  }
}

class _ResolvedItem {
  final LibraryItem item;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int runtimeMinutes; // per episode (tv) or per movie
  final int totalEpisodeCount; // tv only, 0 for movies
  final bool isEnded; // tv only
  final String? status; // tv only, raw TMDB status (e.g. "Canceled")

  _ResolvedItem({
    required this.item,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.runtimeMinutes,
    this.totalEpisodeCount = 0,
    this.isEnded = false,
    this.status,
  });

  int get watchedEpisodesCount => item.watchedEpisodes.values.where((w) => w).length;

  /// A movie is "watched" via its own flag; a series is "watched" once every
  /// released episode has been checked off.
  bool get isWatched =>
      item.type == 'movie' ? item.watched : (totalEpisodeCount > 0 && watchedEpisodesCount >= totalEpisodeCount);

  DateTime get recency => item.lastActivityAt ?? item.watchedAt ?? item.addedAt;
}

class _WatchTime {
  final int months;
  final int days;
  final int hours;

  _WatchTime(int totalMinutes)
      : hours = (totalMinutes ~/ 60) % 24,
        days = (totalMinutes ~/ (60 * 24)) % 30,
        months = totalMinutes ~/ (60 * 24 * 30);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfileBody(
      items: context.watch<LibraryProvider>().items,
      tmdb: context.read<TmdbService>(),
      user: context.watch<AuthProvider>().user,
      lists: context.watch<ListsProvider>().lists,
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final List<LibraryItem> items;
  final TmdbService tmdb;
  final User? user;
  final List<WatchList> lists;

  const _ProfileBody({required this.items, required this.tmdb, required this.user, required this.lists});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final Map<String, _ResolvedItem> _resolved = {};
  bool _showContent = false;

  String _key(LibraryItem item) => '${item.type}:${item.tmdbId}';

  @override
  void initState() {
    super.initState();
    _resolveAll(widget.items, isInitial: true);
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ProfileScreen watches Library, Auth, and Lists providers together, so
    // this widget rebuilds whenever any of them changes — not just when the
    // library actually did. LibraryProvider only hands out a new `items`
    // list when its own Firestore listener fires, so an unrelated rebuild
    // (renaming a list, editing the display name) passes the exact same
    // list reference back down. Re-resolving anyway discarded the already-
    // rendered profile back to the loading skeleton for no reason, which is
    // what made it feel like every visit had to re-fetch from scratch.
    if (!identical(oldWidget.items, widget.items)) {
      _resolveAll(widget.items, isInitial: false);
    }
  }

  // Each title resolves and renders independently the moment it's ready,
  // instead of the old all-or-nothing Future.wait that held the entire
  // profile back on the single slowest/cold-cache title. On first load we
  // still give the batch a brief head start so a warm cache paints in one
  // shot with no skeleton flash at all, while a cold one shows whatever's
  // ready after 600ms and lets the rest pop in.
  Future<void> _resolveAll(List<LibraryItem> items, {required bool isInitial}) {
    final keys = items.map(_key).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));

    final List<Future<void>> futures = items.map((item) {
      final key = _key(item);
      return _resolveItem(widget.tmdb, item).then<void>((r) {
        if (mounted) setState(() => _resolved[key] = r);
      }).catchError((_) {
        // A single title failing to load (TMDB hiccup) shouldn't block the
        // rest of the profile from rendering.
      });
    }).toList();

    final all = Future.wait(futures);
    if (isInitial) {
      all.timeout(const Duration(milliseconds: 600), onTimeout: () => <void>[]).whenComplete(() {
        if (mounted) setState(() => _showContent = true);
      });
    }
    return all;
  }

  Future<void> _refresh() async {
    widget.tmdb.clearCache();
    await _resolveAll(widget.items, isInitial: false);
  }

  Future<void> _createList(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nouvelle liste'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom de la liste'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<ListsService>().createList(uid: uid, name: name);
    }
  }

  Future<void> _editDisplayName(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Modifier le profil'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AuthProvider>().updateDisplayName(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final lists = widget.lists;

    if (!_showContent) {
      return const Scaffold(body: ProfileSkeleton());
    }

    final resolved = widget.items.map((i) => _resolved[_key(i)]).whereType<_ResolvedItem>().toList();

        final series = resolved.where((r) => r.item.type == 'tv').toList()
          ..sort((a, b) => b.recency.compareTo(a.recency));
        final seriesFav = resolved.where((r) => r.item.type == 'tv' && r.item.favorite).toList()
          ..sort((a, b) => (b.item.favoritedAt ?? b.recency).compareTo(a.item.favoritedAt ?? a.recency));
        final films = resolved.where((r) => r.item.type == 'movie').toList()
          ..sort((a, b) => b.recency.compareTo(a.recency));
        final filmsFav = resolved.where((r) => r.item.type == 'movie' && r.item.favorite).toList()
          ..sort((a, b) => (b.item.favoritedAt ?? b.recency).compareTo(a.item.favoritedAt ?? a.recency));

        final episodesWatched = series.fold<int>(0, (sum, r) => sum + r.watchedEpisodesCount);
        final seriesMinutes =
            series.fold<int>(0, (sum, r) => sum + r.watchedEpisodesCount * r.runtimeMinutes);
        final filmsMinutes =
            films.fold<int>(0, (sum, r) => sum + (r.item.watched ? r.runtimeMinutes : 0));

        String? bannerBackdrop;
        if (resolved.isNotEmpty) {
          final mostRecent = resolved.reduce((a, b) => a.recency.isAfter(b.recency) ? a : b);
          bannerBackdrop = mostRecent.backdropPath ?? mostRecent.posterPath;
        }

        final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Utilisateur';

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _ProfileHeader(
                  backdropPath: bannerBackdrop,
                  photoUrl: user?.photoURL,
                  displayName: displayName,
                  onEdit: () => _editDisplayName(context, displayName),
                  onSignOut: () => context.read<AuthProvider>().signOut(),
                  onImport: () => Navigator.of(context).push(appRoute(
                    builder: (_) => const ImportTvTimeScreen(),
                  )),
                ),
                const SizedBox(height: 8),
                _StatsRow(
                  seriesCount: series.where((r) => r.isWatched).length,
                  filmsCount: films.where((r) => r.isWatched).length,
                  episodesWatched: episodesWatched,
                ),
                const Divider(height: 33, indent: 16, endIndent: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).push(appRoute(builder: (_) => const FriendsScreen())),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 33, indent: 16, endIndent: 16),
                const _SectionHeader(title: 'Statistiques'),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _StatCard(icon: Icons.tv, label: 'Temps passé devant des séries', minutes: seriesMinutes),
                      _StatCard(icon: Icons.movie, label: 'Temps passé devant des films', minutes: filmsMinutes),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 33, indent: 16, endIndent: 16),
                const _SectionHeader(title: 'Listes'),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _CreateListCard(onTap: () => _createList(context)),
                      ...lists.map((l) => _ListCard(
                            list: l,
                            onTap: () => Navigator.of(context).push(appRoute(
                              builder: (_) => ListDetailScreen(listId: l.id),
                            )),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 33, indent: 16, endIndent: 16),
                _CarouselSection(title: 'Séries', items: series),
                _CarouselSection(title: 'Séries préférées', items: seriesFav, showHeart: true),
                _CarouselSection(title: 'Films', items: films),
                _CarouselSection(title: 'Films préférés', items: filmsFav, showHeart: true),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    TmdbConfig.attribution,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? backdropPath;
  final String? photoUrl;
  final String displayName;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;
  final VoidCallback onImport;

  const _ProfileHeader({
    required this.backdropPath,
    required this.photoUrl,
    required this.displayName,
    required this.onEdit,
    required this.onSignOut,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    const bannerHeight = 220.0;
    const avatarSize = 84.0;
    const spacer = 48.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            SizedBox(
              height: bannerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropPath != null)
                    CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrlLarge}$backdropPath',
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.surfaceVariant),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: SafeArea(
                      bottom: false,
                      child: PopupMenuButton<void>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: AppColors.surface,
                        itemBuilder: (context) => [
                          PopupMenuItem(onTap: onImport, child: const Text('Importer depuis TV Time')),
                          PopupMenuItem(onTap: onSignOut, child: const Text('Se déconnecter')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: spacer),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 3),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize,
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(Icons.person, color: AppColors.textSecondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('MODIFIER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int seriesCount;
  final int filmsCount;
  final int episodesWatched;

  const _StatsRow({required this.seriesCount, required this.filmsCount, required this.episodesWatched});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: _StatColumn(value: seriesCount, label: 'séries vues')),
          const SizedBox(height: 40, child: VerticalDivider(width: 1)),
          Expanded(child: _StatColumn(value: filmsCount, label: 'films vus')),
          const SizedBox(height: 40, child: VerticalDivider(width: 1)),
          Expanded(child: _StatColumn(value: episodesWatched, label: 'épisodes vus')),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int minutes;

  const _StatCard({required this.icon, required this.label, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final time = _WatchTime(minutes);
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TimeUnit(value: time.months, label: 'MOIS'),
              _TimeUnit(value: time.days, label: 'JOURS'),
              _TimeUnit(value: time.hours, label: 'HEURES'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;

  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _CreateListCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateListCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'CRÉER UNE LISTE',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final WatchList list;
  final VoidCallback onTap;

  const _ListCard({required this.list, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.playlist_play, color: AppColors.accent),
            const SizedBox(height: 10),
            Text(list.name,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${list.items.length} élément(s)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CarouselSection extends StatelessWidget {
  final String title;
  final List<_ResolvedItem> items;
  final bool showHeart;
  final bool readOnly;

  const _CarouselSection({
    required this.title,
    required this.items,
    this.showHeart = false,
    this.readOnly = false,
  });

  static const _carouselCap = 20;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final visible = items.take(_carouselCap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(appRoute(
            builder: (_) => _FullListScreen(title: title, items: items, readOnly: readOnly),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (showHeart)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.favorite, color: Colors.white, size: 14),
                      ),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final resolved = visible[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(appRoute(
                      builder: (_) => readOnly
                          ? (resolved.item.type == 'tv'
                              ? ShowDetailScreen.preview(tmdbId: resolved.item.tmdbId)
                              : MovieDetailScreen.preview(tmdbId: resolved.item.tmdbId))
                          : (resolved.item.type == 'tv'
                              ? ShowDetailScreen(libraryItem: resolved.item)
                              : MovieDetailScreen(libraryItem: resolved.item)),
                    ));
                  },
                  child: SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: resolved.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: '${TmdbConfig.imageBaseUrlSmall}${resolved.posterPath}',
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
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

enum _SeriesProgressFilter { all, inProgress, notStarted, upToDate, completed, cancelled, favorites }

extension on _SeriesProgressFilter {
  String get label => switch (this) {
        _SeriesProgressFilter.all => 'Tout',
        _SeriesProgressFilter.inProgress => 'Vos séries en cours',
        _SeriesProgressFilter.notStarted => "N'a pas encore commencé",
        _SeriesProgressFilter.upToDate => 'À jour',
        _SeriesProgressFilter.completed => 'Terminé',
        _SeriesProgressFilter.cancelled => 'Arrêtées',
        _SeriesProgressFilter.favorites => 'Favoris',
      };
}

enum _FilmProgressFilter { all, watched, unwatched, favorites }

extension on _FilmProgressFilter {
  String get label => switch (this) {
        _FilmProgressFilter.all => 'Tous',
        _FilmProgressFilter.watched => 'Vu',
        _FilmProgressFilter.unwatched => 'Non vu',
        _FilmProgressFilter.favorites => 'Favoris',
      };
}

/// Cancelled takes priority over watch progress (there will never be more
/// episodes), then completion, then whether anything has been watched.
_SeriesProgressFilter _categorizeSeries(_ResolvedItem r) {
  if (r.status == 'Canceled') return _SeriesProgressFilter.cancelled;
  final total = r.totalEpisodeCount;
  final watched = r.watchedEpisodesCount;
  if (total > 0 && watched >= total) {
    return r.isEnded ? _SeriesProgressFilter.completed : _SeriesProgressFilter.upToDate;
  }
  if (watched == 0) return _SeriesProgressFilter.notStarted;
  return _SeriesProgressFilter.inProgress;
}

class _FullListScreen extends StatefulWidget {
  final String title;
  final List<_ResolvedItem> items;
  final bool readOnly;

  const _FullListScreen({required this.title, required this.items, this.readOnly = false});

  @override
  State<_FullListScreen> createState() => _FullListScreenState();
}

class _FullListScreenState extends State<_FullListScreen> {
  late final bool _isSeries = widget.items.first.item.type == 'tv';
  late List<_ResolvedItem> _items = widget.items;
  LibrarySort _sort = LibrarySort.lastActivity;
  _SeriesProgressFilter _seriesFilter = _SeriesProgressFilter.all;
  _FilmProgressFilter _filmFilter = _FilmProgressFilter.all;
  bool _grouped = false;

  Future<void> _refresh() async {
    final tmdb = context.read<TmdbService>();
    tmdb.clearCache();
    final refreshed = await Future.wait(_items.map((r) async {
      try {
        return await _resolveItem(tmdb, r.item);
      } catch (_) {
        return r;
      }
    }));
    if (mounted) setState(() => _items = refreshed);
  }

  // Series get a proportional progress bar; movies are binary (watched or
  // not) so they get a corner check badge instead — a full-width bar reading
  // either "empty" or "full" isn't actually communicating a progress amount.
  double? _progressRatio(_ResolvedItem r) {
    if (r.item.type == 'movie') return null;
    if (r.totalEpisodeCount <= 0) return null;
    return (r.watchedEpisodesCount / r.totalEpisodeCount).clamp(0.0, 1.0);
  }

  Color _progressColor(_ResolvedItem r, double ratio) {
    if (ratio < 1.0) return AppColors.accent;
    if (r.item.type == 'tv' && r.isEnded) return Colors.purple;
    return Colors.green;
  }

  Future<void> _openFilterSheet() async {
    if (_isSeries) {
      final result = await showLibraryFilterSheet<_SeriesProgressFilter>(
        context,
        initialSort: _sort,
        progressTitle: 'Progress',
        filterValues: _SeriesProgressFilter.values,
        filterLabel: (f) => f.label,
        initialFilter: _seriesFilter,
        defaultFilter: _SeriesProgressFilter.all,
      );
      if (result != null && mounted) {
        setState(() {
          _sort = result.sort;
          _seriesFilter = result.filter;
        });
      }
    } else {
      final result = await showLibraryFilterSheet<_FilmProgressFilter>(
        context,
        initialSort: _sort,
        progressTitle: 'Avancement',
        filterValues: _FilmProgressFilter.values,
        filterLabel: (f) => f.label,
        initialFilter: _filmFilter,
        defaultFilter: _FilmProgressFilter.all,
      );
      if (result != null && mounted) {
        setState(() {
          _sort = result.sort;
          _filmFilter = result.filter;
        });
      }
    }
  }

  bool _matchesFilter(_ResolvedItem r) {
    if (_isSeries) {
      switch (_seriesFilter) {
        case _SeriesProgressFilter.all:
          return true;
        case _SeriesProgressFilter.favorites:
          return r.item.favorite;
        case _SeriesProgressFilter.inProgress:
        case _SeriesProgressFilter.notStarted:
        case _SeriesProgressFilter.upToDate:
        case _SeriesProgressFilter.completed:
        case _SeriesProgressFilter.cancelled:
          return _categorizeSeries(r) == _seriesFilter;
      }
    }
    switch (_filmFilter) {
      case _FilmProgressFilter.all:
        return true;
      case _FilmProgressFilter.watched:
        return r.item.watched;
      case _FilmProgressFilter.unwatched:
        return !r.item.watched;
      case _FilmProgressFilter.favorites:
        return r.item.favorite;
    }
  }

  List<_ResolvedItem> _applyFilterAndSort() {
    final filtered = _items.where(_matchesFilter).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case LibrarySort.lastActivity:
          return b.recency.compareTo(a.recency);
        case LibrarySort.lastAdded:
          return b.item.addedAt.compareTo(a.item.addedAt);
        case LibrarySort.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return filtered;
  }

  Widget _buildTile(_ResolvedItem resolved) {
    final ratio = _progressRatio(resolved);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(appRoute(
        builder: (_) => widget.readOnly
            ? (resolved.item.type == 'tv'
                ? ShowDetailScreen.preview(tmdbId: resolved.item.tmdbId)
                : MovieDetailScreen.preview(tmdbId: resolved.item.tmdbId))
            : (resolved.item.type == 'tv'
                ? ShowDetailScreen(libraryItem: resolved.item)
                : MovieDetailScreen(libraryItem: resolved.item)),
      )),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Hero(
              tag: posterHeroTag(resolved.item.type, resolved.item.tmdbId),
              child: resolved.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrlMedium}${resolved.posterPath}',
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.tv, color: AppColors.textSecondary),
                    ),
            ),
          ),
          if (ratio != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedProgressBar(
                value: ratio,
                color: _progressColor(resolved, ratio),
                backgroundColor: Colors.black45,
                height: 6,
              ),
            ),
          if (resolved.item.type == 'movie')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(
                  resolved.item.watched ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: resolved.item.watched ? Colors.greenAccent : Colors.white70,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Sticky section pills, shown when the eye toggle is on — mirrors TV
  // Time's grouped library view. Sections are derived from progress, not
  // from the active filter, so e.g. filtering to "Favoris" still groups the
  // favorited titles by where they stand.
  List<MapEntry<String, List<_ResolvedItem>>> _buildGroups(List<_ResolvedItem> visible) {
    final groups = <MapEntry<String, List<_ResolvedItem>>>[];
    if (_isSeries) {
      const order = [
        (_SeriesProgressFilter.inProgress, 'EN COURS'),
        (_SeriesProgressFilter.notStarted, 'PAS COMMENCÉ'),
        (_SeriesProgressFilter.upToDate, 'À JOUR'),
        (_SeriesProgressFilter.completed, 'TERMINÉ'),
        (_SeriesProgressFilter.cancelled, 'ARRÊTÉE'),
      ];
      for (final (category, label) in order) {
        final items = visible.where((r) => _categorizeSeries(r) == category).toList();
        if (items.isNotEmpty) groups.add(MapEntry(label, items));
      }
    } else {
      final unwatched = visible.where((r) => !r.item.watched).toList();
      final watched = visible.where((r) => r.item.watched).toList();
      if (unwatched.isNotEmpty) groups.add(MapEntry('PAS VU', unwatched));
      if (watched.isNotEmpty) groups.add(MapEntry('VU', watched));
    }
    return groups;
  }

  Widget _buildGroupedGrid(List<_ResolvedItem> visible) {
    final groups = _buildGroups(visible);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Each section's pinned header + grid are grouped so the pin is
        // released to the next section's header exactly when it arrives —
        // separate top-level SliverPersistentHeaders never hand off and
        // just stack forever instead of replacing one another.
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyPillHeaderDelegate(label: group.key, onTap: _openFilterSheet),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => FadeInEntry(index: index, child: _buildTile(group.value[index])),
                    childCount: group.value.length,
                  ),
                ),
              ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _applyFilterAndSort();
    final filterLabel = _isSeries ? _seriesFilter.label : _filmFilter.label;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _grouped = !_grouped),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _grouped ? AppColors.accent : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility,
                  size: 20,
                  color: _grouped ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  // In grouped mode, the sticky per-section pills (En cours,
                  // Pas commencé...) take over as the top badge — showing
                  // both would mean two stacked pills before any content.
                  if (!_grouped) LibraryFilterBadge(label: filterLabel, onTap: _openFilterSheet),
                  if (visible.isEmpty)
                    const Expanded(
                      child: ScrollableCenter(
                        child: Text('Aucun titre ne correspond à ce filtre.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    Expanded(
                      child: _grouped
                          ? _buildGroupedGrid(visible)
                          : GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.6,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (context, index) =>
                                  FadeInEntry(index: index, child: _buildTile(visible[index])),
                            ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: LibraryFilterButton(onTap: _openFilterSheet)),
          ),
        ],
      ),
    );
  }
}

class _StickyPillHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final VoidCallback onTap;

  const _StickyPillHeaderDelegate({required this.label, required this.onTap});

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  // Transparent everywhere but the pill itself, so it reads as a floating
  // badge over the scrolling posters (matching LibraryFilterBadge) rather
  // than a solid bar painted across the header's whole width.
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return LibraryFilterBadge(label: label, onTap: onTap);
  }

  @override
  bool shouldRebuild(covariant _StickyPillHeaderDelegate oldDelegate) =>
      oldDelegate.label != label || oldDelegate.onTap != onTap;
}

/// Read-only view of a friend's profile, mirroring [ProfileScreen]'s layout
/// (banner, avatar, stats, carousels) so every profile looks the same —
/// only the data source (a friend's uid instead of the current user's) and
/// the lack of edit affordances differ. Poster taps open detail screens in
/// preview mode since these items belong to someone else's library.
class FriendProfileScreen extends StatefulWidget {
  final String friendUid;
  final String displayName;
  final String? photoUrl;

  const FriendProfileScreen({
    super.key,
    required this.friendUid,
    required this.displayName,
    this.photoUrl,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  StreamSubscription<List<LibraryItem>>? _subscription;
  List<LibraryItem> _libraryItems = [];
  final Map<String, _ResolvedItem> _resolved = {};
  bool _hasData = false;
  bool _showContent = false;
  Object? _streamError;

  String _key(LibraryItem item) => '${item.type}:${item.tmdbId}';

  @override
  void initState() {
    super.initState();
    _subscription = context.read<LibraryService>().watchLibrary(widget.friendUid).listen(
      (items) {
        final isInitial = !_hasData;
        _libraryItems = items;
        _hasData = true;
        _streamError = null;
        if (mounted) setState(() {});
        _resolveAll(items, isInitial: isInitial);
      },
      onError: (e) {
        if (mounted) setState(() => _streamError = e);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Same progressive-resolution approach as ProfileScreen: each title
  // renders as soon as it resolves instead of the whole profile waiting on
  // Future.wait, and — unlike the old StreamBuilder+FutureBuilder nesting —
  // resolving isn't rebuilt from scratch on every single Firestore emission.
  Future<void> _resolveAll(List<LibraryItem> items, {required bool isInitial}) {
    final tmdb = context.read<TmdbService>();
    final keys = items.map(_key).toSet();
    _resolved.removeWhere((k, _) => !keys.contains(k));

    final List<Future<void>> futures = items.map((item) {
      final key = _key(item);
      return _resolveItem(tmdb, item).then<void>((r) {
        if (mounted) setState(() => _resolved[key] = r);
      }).catchError((_) {
        // A single title failing to load (TMDB hiccup) shouldn't block the
        // rest of the profile from rendering.
      });
    }).toList();

    final all = Future.wait(futures);
    if (isInitial) {
      all.timeout(const Duration(milliseconds: 600), onTimeout: () => <void>[]).whenComplete(() {
        if (mounted) setState(() => _showContent = true);
      });
    }
    return all;
  }

  Future<void> _refresh() async {
    context.read<TmdbService>().clearCache();
    await _resolveAll(_libraryItems, isInitial: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ScrollableCenter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Impossible d'accéder à ce profil.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_streamError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!_hasData || !_showContent) {
      return const Scaffold(body: ProfileSkeleton());
    }

    final resolved = _libraryItems.map((i) => _resolved[_key(i)]).whereType<_ResolvedItem>().toList();

    final series = resolved.where((r) => r.item.type == 'tv').toList();
    final seriesFav = series.where((r) => r.item.favorite).toList();
    final films = resolved.where((r) => r.item.type == 'movie').toList();
    final filmsFav = films.where((r) => r.item.favorite).toList();
    final episodesWatched = series.fold<int>(0, (sum, r) => sum + r.watchedEpisodesCount);

    String? bannerBackdrop;
    if (resolved.isNotEmpty) {
      final mostRecent = resolved.reduce((a, b) => a.recency.isAfter(b.recency) ? a : b);
      bannerBackdrop = mostRecent.backdropPath ?? mostRecent.posterPath;
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _FriendProfileHeader(
              backdropPath: bannerBackdrop,
              photoUrl: widget.photoUrl,
              displayName: widget.displayName,
            ),
            const SizedBox(height: 8),
            _StatsRow(
              seriesCount: series.where((r) => r.isWatched).length,
              filmsCount: films.where((r) => r.isWatched).length,
              episodesWatched: episodesWatched,
            ),
            const Divider(height: 33, indent: 16, endIndent: 16),
            _CarouselSection(title: 'Séries', items: series, readOnly: true),
            _CarouselSection(title: 'Séries préférées', items: seriesFav, showHeart: true, readOnly: true),
            _CarouselSection(title: 'Films', items: films, readOnly: true),
            _CarouselSection(title: 'Films préférés', items: filmsFav, showHeart: true, readOnly: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FriendProfileHeader extends StatelessWidget {
  final String? backdropPath;
  final String? photoUrl;
  final String displayName;

  const _FriendProfileHeader({
    required this.backdropPath,
    required this.photoUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    const bannerHeight = 220.0;
    const avatarSize = 84.0;
    const spacer = 48.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            SizedBox(
              height: bannerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropPath != null)
                    CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrlLarge}$backdropPath',
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.surfaceVariant),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: SafeArea(
                      bottom: false,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: spacer),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 3),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize,
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(Icons.person, color: AppColors.textSecondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Text(displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}
