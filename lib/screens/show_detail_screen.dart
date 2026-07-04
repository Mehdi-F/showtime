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
import '../widgets/add_to_list_sheet.dart';
import '../widgets/media_info_sections.dart';
import '../widgets/round_check.dart';

class ShowDetailScreen extends StatefulWidget {
  final LibraryItem libraryItem;

  const ShowDetailScreen({super.key, required this.libraryItem});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> with SingleTickerProviderStateMixin {
  TvDetails? _details;
  int _selectedSeason = 1;
  SeasonDetails? _seasonDetails;
  Map<String, bool> _watchedEpisodes = {};
  late bool _favorite;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _watchedEpisodes = Map.of(widget.libraryItem.watchedEpisodes);
    _favorite = widget.libraryItem.favorite;
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final newValue = !_favorite;
    setState(() => _favorite = newValue);
    await context.read<LibraryService>().toggleFavorite(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          type: 'tv',
          favorite: newValue,
        );
  }

  Future<void> _unfollow() async {
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().removeFromLibrary(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          type: 'tv',
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _load() async {
    final tmdb = context.read<TmdbService>();
    final details = await tmdb.getTvDetails(widget.libraryItem.tmdbId);
    setState(() {
      _details = details;
      _selectedSeason = details.seasons.isNotEmpty ? details.seasons.first.seasonNumber : 1;
    });
    await _loadSeason(_selectedSeason);
  }

  Future<void> _loadSeason(int seasonNumber) async {
    final tmdb = context.read<TmdbService>();
    final season = await tmdb.getSeasonDetails(widget.libraryItem.tmdbId, seasonNumber);
    setState(() {
      _selectedSeason = seasonNumber;
      _seasonDetails = season;
    });
  }

  Future<void> _toggleEpisode(EpisodeRef ep) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final newValue = !(_watchedEpisodes[ep.key] ?? false);
    setState(() => _watchedEpisodes[ep.key] = newValue);
    await context.read<LibraryService>().markEpisodeWatched(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          season: ep.seasonNumber,
          episode: ep.episodeNumber,
          watched: newValue,
        );
  }

  Future<void> _markSeasonWatched(bool watched) async {
    final season = _seasonDetails;
    if (season == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    setState(() {
      for (final ep in season.episodes) {
        _watchedEpisodes[ep.key] = watched;
      }
    });
    await context.read<LibraryService>().markSeasonWatched(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          season: _selectedSeason,
          episodeNumbers: season.episodes.map((e) => e.episodeNumber).toList(),
          watched: watched,
        );
  }

  Future<void> _openSimilar(SimilarMedia media) async {
    final matches = context
        .read<LibraryProvider>()
        .items
        .where((i) => i.tmdbId == media.id && i.type == media.type);
    LibraryItem item;
    if (matches.isNotEmpty) {
      item = matches.first;
    } else {
      final uid = context.read<AuthProvider>().user!.uid;
      item = await context.read<LibraryService>().addToLibrary(
            uid: uid,
            tmdbId: media.id,
            type: media.type,
          );
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShowDetailScreen(libraryItem: item),
    ));
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildAboutTab(TvDetails details) {
    final tmdb = context.read<TmdbService>();
    final String? yearRange;
    if (details.firstAirYear == null) {
      yearRange = null;
    } else if (!details.isEnded) {
      yearRange = '${details.firstAirYear} - présent';
    } else if (details.lastAirYear != null && details.lastAirYear != details.firstAirYear) {
      yearRange = '${details.firstAirYear} - ${details.lastAirYear}';
    } else {
      yearRange = '${details.firstAirYear}';
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        InfoCard(
          yearRange: yearRange,
          genres: details.genres,
          voteAverage: details.voteAverage,
          overview: details.overview,
          runtimeMinutes: details.episodeRunTime,
          addedCaption: 'Ajoutée à votre bibliothèque le ${_formatDate(widget.libraryItem.addedAt)}',
        ),
        CastRow(future: tmdb.getTvCredits(widget.libraryItem.tmdbId)),
        SimilarRow(
          title: 'Les utilisateurs ont également regardé',
          future: tmdb.getSimilarTv(widget.libraryItem.tmdbId),
          onTap: _openSimilar,
        ),
      ],
    );
  }

  Widget _buildEpisodesTab(TvDetails details, List<EpisodeRef> seasonEpisodes, int watchedCount, double progress) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              ...details.seasons.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s.name),
                      selected: _selectedSeason == s.seasonNumber,
                      onSelected: (_) => _loadSeason(s.seasonNumber),
                    ),
                  )),
              if (details.hasSpecials)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('Spéciaux'),
                    selected: _selectedSeason == 0,
                    onSelected: (_) => _loadSeason(0),
                  ),
                ),
            ],
          ),
        ),
        if (seasonEpisodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$watchedCount/${seasonEpisodes.length}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _markSeasonWatched(true),
                child: const Text('Mark season watched'),
              ),
              TextButton(
                onPressed: () => _markSeasonWatched(false),
                child: const Text('Mark season unwatched'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _seasonDetails == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: seasonEpisodes.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ep = seasonEpisodes[index];
                    final watched = _watchedEpisodes[ep.key] ?? false;
                    return ListTile(
                      title: Text('${ep.episodeNumber}. ${ep.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: RoundCheck(
                        checked: watched,
                        onTap: () => _toggleEpisode(ep),
                      ),
                      onTap: () => _toggleEpisode(ep),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final seasonEpisodes = _seasonDetails?.episodes ?? const [];
    final watchedCount = seasonEpisodes.where((e) => _watchedEpisodes[e.key] ?? false).length;
    final progress = seasonEpisodes.isEmpty ? 0.0 : watchedCount / seasonEpisodes.length;

    return Scaffold(
      body: Column(
        children: [
          _ShowBanner(
            title: details.name,
            posterPath: details.posterPath,
            isEnded: details.isEnded,
            favorite: _favorite,
            onToggleFavorite: _toggleFavorite,
            onUnfollow: _unfollow,
            onAddToList: () => showAddToListSheet(
              context,
              tmdbId: widget.libraryItem.tmdbId,
              type: 'tv',
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            tabs: const [Tab(text: 'À PROPOS'), Tab(text: 'ÉPISODES')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(details),
                _buildEpisodesTab(details, seasonEpisodes, watchedCount, progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowBanner extends StatelessWidget {
  final String title;
  final String? posterPath;
  final bool isEnded;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onUnfollow;
  final VoidCallback onAddToList;

  const _ShowBanner({
    required this.title,
    required this.posterPath,
    required this.isEnded,
    required this.favorite,
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
          if (posterPath != null)
            CachedNetworkImage(
              imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
              fit: BoxFit.cover,
            )
          else
            Container(color: AppColors.surfaceVariant),
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
                      IconButton(
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          color: favorite ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: onToggleFavorite,
                      ),
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
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isEnded ? AppColors.surfaceVariant : AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEnded ? 'Terminée' : 'En cours',
                    style: TextStyle(
                      color: isEnded ? Colors.white : Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
