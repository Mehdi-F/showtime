import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/discover_poster_tile.dart';
import '../widgets/media_list_tile.dart';
import 'discover_grid_screen.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TmdbSearchResult> _results = [];
  bool _loading = false;
  bool _showDiscover = true;
  String? _error;

  late Future<List<SimilarMedia>> _topRatedTv;
  late Future<List<SimilarMedia>> _trendingTv;
  late Future<List<SimilarMedia>> _popularTv;
  late Future<List<SimilarMedia>> _trendingMovies;
  late Future<List<SimilarMedia>> _popularMovies;

  @override
  void initState() {
    super.initState();
    _loadDiscover();
  }

  void _loadDiscover() {
    final tmdb = context.read<TmdbService>();
    _topRatedTv = tmdb.getTopRatedTv();
    _trendingTv = tmdb.getTrending('tv');
    _popularTv = tmdb.getPopular('tv');
    _trendingMovies = tmdb.getTrending('movie');
    _popularMovies = tmdb.getPopular('movie');
  }

  Future<void> _refreshDiscover() async {
    setState(_loadDiscover);
    await Future.wait([_topRatedTv, _trendingTv, _popularTv, _trendingMovies, _popularMovies]);
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<TmdbService>().search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'Search failed. Check your connection and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user!.uid;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Rechercher',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _showDiscover = value.trim().isEmpty),
          onSubmitted: _runSearch,
        ),
      ),
      body: _showDiscover ? _buildDiscover() : _buildSearchResults(uid),
    );
  }

  Widget _buildSearchResults(String uid) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)));
    }
    final libraryItems = context.watch<LibraryProvider>().items;
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        LibraryItem? existing;
        for (final i in libraryItems) {
          if (i.tmdbId == result.id && i.type == result.mediaType) existing = i;
        }
        final added = existing != null;

        void openDetail() {
          final item = existing;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) {
              if (result.mediaType == 'tv') {
                return item != null ? ShowDetailScreen(libraryItem: item) : ShowDetailScreen.preview(tmdbId: result.id);
              }
              return item != null ? MovieDetailScreen(libraryItem: item) : MovieDetailScreen.preview(tmdbId: result.id);
            },
          ));
        }

        return MediaListTile(
          posterPath: result.posterPath,
          title: result.year != null ? '${result.title} (${result.year})' : result.title,
          subtitle: result.mediaType == 'tv' ? 'Series' : 'Film',
          onTap: openDetail,
          trailing: IconButton(
            icon: Icon(
              added ? Icons.check_circle : Icons.add_circle_outline,
              color: added ? Colors.greenAccent : AppColors.accent,
            ),
            onPressed: () async {
              final library = context.read<LibraryService>();
              if (added) {
                await library.removeFromLibrary(uid: uid, tmdbId: result.id, type: result.mediaType);
              } else {
                await library.addToLibrary(uid: uid, tmdbId: result.id, type: result.mediaType);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscover() {
    return RefreshIndicator(
      onRefresh: _refreshDiscover,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          _CategoryRow(title: 'Meilleures séries pour vous', future: _topRatedTv),
          _CategoryRow(title: 'Séries tendance', future: _trendingTv),
          _CategoryRow(title: 'Populaire dans votre pays', future: _popularTv),
          _BrowseAllButton(
            icon: Icons.tv,
            label: 'PARCOURIR TOUTES LES SÉRIES',
            mediaType: 'tv',
            screenTitle: 'Toutes les séries',
          ),
          const SizedBox(height: 16),
          _CategoryRow(title: 'Films tendance', future: _trendingMovies),
          _CategoryRow(title: 'Films populaires', future: _popularMovies),
          _BrowseAllButton(
            icon: Icons.movie,
            label: 'PARCOURIR TOUS LES FILMS',
            mediaType: 'movie',
            screenTitle: 'Tous les films',
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String title;
  final Future<List<SimilarMedia>> future;

  const _CategoryRow({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    final followedKeys =
        context.watch<LibraryProvider>().items.map((i) => '${i.type}_${i.tmdbId}').toSet();
    return FutureBuilder<List<SimilarMedia>>(
      future: future,
      builder: (context, snapshot) {
        final items =
            (snapshot.data ?? const []).where((m) => !followedKeys.contains('${m.type}_${m.id}')).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DiscoverPosterTile(media: items[index], width: 100, height: 140),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BrowseAllButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String mediaType;
  final String screenTitle;

  const _BrowseAllButton({
    required this.icon,
    required this.label,
    required this.mediaType,
    required this.screenTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DiscoverGridScreen(mediaType: mediaType, title: screenTitle),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.black),
                    const SizedBox(width: 10),
                    Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Icon(Icons.chevron_right, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
