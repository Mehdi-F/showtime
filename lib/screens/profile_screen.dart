import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/watch_list.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/lists_provider.dart';
import '../services/lists_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'list_detail_screen.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

class _ResolvedItem {
  final LibraryItem item;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int runtimeMinutes; // per episode (tv) or per movie

  _ResolvedItem({
    required this.item,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.runtimeMinutes,
  });

  int get watchedEpisodesCount => item.watchedEpisodes.values.where((w) => w).length;

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

  Future<_ResolvedItem> _resolve(TmdbService tmdb, LibraryItem item) async {
    if (item.type == 'tv') {
      final details = await tmdb.getTvDetails(item.tmdbId);
      return _ResolvedItem(
        item: item,
        title: details.name,
        posterPath: details.posterPath,
        backdropPath: details.backdropPath,
        runtimeMinutes: details.episodeRunTime,
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
    final items = context.watch<LibraryProvider>().items;
    final tmdb = context.read<TmdbService>();
    final user = context.watch<AuthProvider>().user;
    final lists = context.watch<ListsProvider>().lists;

    return FutureBuilder<List<_ResolvedItem>>(
      future: Future.wait(items.map((i) => _resolve(tmdb, i))),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final series = resolved.where((r) => r.item.type == 'tv').toList();
        final seriesFav = series.where((r) => r.item.favorite).toList();
        final films = resolved.where((r) => r.item.type == 'movie').toList();
        final filmsFav = films.where((r) => r.item.favorite).toList();

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
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHeader(
                backdropPath: bannerBackdrop,
                photoUrl: user?.photoURL,
                displayName: displayName,
                onEdit: () => _editDisplayName(context, displayName),
                onSignOut: () => context.read<AuthProvider>().signOut(),
              ),
              const SizedBox(height: 8),
              _StatsRow(seriesCount: series.length, filmsCount: films.length, episodesWatched: episodesWatched),
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
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
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
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? backdropPath;
  final String? photoUrl;
  final String displayName;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  const _ProfileHeader({
    required this.backdropPath,
    required this.photoUrl,
    required this.displayName,
    required this.onEdit,
    required this.onSignOut,
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
                      imageUrl: '${TmdbConfig.imageBaseUrl}$backdropPath',
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
            crossAxisAlignment: CrossAxisAlignment.end,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
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
          Expanded(child: _StatColumn(value: seriesCount, label: 'séries')),
          const SizedBox(height: 40, child: VerticalDivider(width: 1)),
          Expanded(child: _StatColumn(value: filmsCount, label: 'films')),
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

  const _CarouselSection({required this.title, required this.items, this.showHeart = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final resolved = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => resolved.item.type == 'tv'
                          ? ShowDetailScreen(libraryItem: resolved.item)
                          : MovieDetailScreen(libraryItem: resolved.item),
                    ));
                  },
                  child: SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: resolved.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: '${TmdbConfig.imageBaseUrl}${resolved.posterPath}',
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
