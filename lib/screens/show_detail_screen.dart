import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/round_check.dart';

class ShowDetailScreen extends StatefulWidget {
  final LibraryItem libraryItem;

  const ShowDetailScreen({super.key, required this.libraryItem});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  TvDetails? _details;
  int _selectedSeason = 1;
  SeasonDetails? _seasonDetails;
  Map<String, bool> _watchedEpisodes = {};

  @override
  void initState() {
    super.initState();
    _watchedEpisodes = Map.of(widget.libraryItem.watchedEpisodes);
    _load();
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
          _ShowBanner(title: details.name, posterPath: details.posterPath),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: details.seasons
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: _selectedSeason == s.seasonNumber,
                          onSelected: (_) => _loadSeason(s.seasonNumber),
                        ),
                      ))
                  .toList(),
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
      ),
    );
  }
}

class _ShowBanner extends StatelessWidget {
  final String title;
  final String? posterPath;

  const _ShowBanner({required this.title, required this.posterPath});

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
            child: SafeArea(
              bottom: false,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
