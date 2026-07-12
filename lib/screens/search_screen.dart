import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_route.dart';
import '../widgets/discover_poster_tile.dart';
import '../widgets/media_list_tile.dart';
import '../widgets/poster_hero_tag.dart';
import '../widgets/skeletons.dart';
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
  Timer? _debounce;
  int _searchToken = 0;

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

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _showDiscover = value.trim().isEmpty);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final token = ++_searchToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<TmdbService>().search(query);
      // A newer search may have superseded this one while it was in flight.
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() => _error = 'Search failed. Check your connection and try again.');
    } finally {
      if (mounted && token == _searchToken) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user!.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(21),
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Rechercher un film, une série...',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (value) {
              _debounce?.cancel();
              _runSearch(value);
            },
          ),
        ),
      ),
      body: _showDiscover ? _buildDiscover() : _buildSearchResults(uid),
    );
  }

  Widget _buildSearchResults(String uid) {
    if (_loading) {
      return const MediaListSkeleton();
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('Aucun résultat pour "${_controller.text.trim()}".',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      );
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
          Navigator.of(context).push(appRoute(
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
          heroTag: posterHeroTag(result.mediaType, result.id),
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

class _CategoryRow extends StatefulWidget {
  final String title;
  final Future<List<SimilarMedia>> future;

  const _CategoryRow({required this.title, required this.future});

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  Future<List<SimilarMedia>>? _resolvedFor;
  List<SimilarMedia>? _visibleItems;

  // The already-followed filter is only applied once, the moment this row's
  // data is fetched — not re-applied on every rebuild. Otherwise tapping the
  // + badge (which adds to the library and notifies LibraryProvider) yanked
  // the title out of the row before the user ever saw it flip to a
  // checkmark. It now stays in place until the row's future is replaced by
  // a fresh fetch (pull-to-refresh), at which point it's correctly excluded.
  //
  // Freezing on the first rebuild also means we must wait for the library's
  // real first snapshot before doing it — right after a fresh app launch,
  // LibraryProvider briefly reports an empty `items` list before Firestore's
  // stream connects, and this TMDB fetch (often served from cache) can well
  // resolve first. Freezing against that transient empty list would lock in
  // "nothing followed", permanently re-showing titles added in past sessions
  // for the rest of that session.
  void _captureBaseline(List<SimilarMedia> data, LibraryProvider library) {
    if (identical(_resolvedFor, widget.future)) return;
    if (!library.isLoaded) return;
    _resolvedFor = widget.future;
    final followedKeys = library.items.map((i) => '${i.type}_${i.tmdbId}').toSet();
    _visibleItems = data.where((m) => !followedKeys.contains('${m.type}_${m.id}')).toList();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return FutureBuilder<List<SimilarMedia>>(
      future: widget.future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        _captureBaseline(data, library);
        final items = _visibleItems;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
          onTap: () => Navigator.of(context).push(appRoute(
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
