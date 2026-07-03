import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(details.name)),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
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
          Padding(
            padding: const EdgeInsets.all(8),
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
                : ListView.builder(
                    itemCount: _seasonDetails!.episodes.length,
                    itemBuilder: (context, index) {
                      final ep = _seasonDetails!.episodes[index];
                      final watched = _watchedEpisodes[ep.key] ?? false;
                      return CheckboxListTile(
                        value: watched,
                        onChanged: (_) => _toggleEpisode(ep),
                        title: Text('${ep.episodeNumber}. ${ep.name}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
