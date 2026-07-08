import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/discover_poster_tile.dart';
import '../widgets/fade_in_entry.dart';
import '../widgets/poster_hero_tag.dart';
import '../widgets/scrollable_center.dart';
import '../widgets/skeletons.dart';

/// Full paginated browse grid over TMDB's general catalog for a media type,
/// sorted by popularity. Reached from the Explorer "Parcourir tout" buttons.
class DiscoverGridScreen extends StatefulWidget {
  final String mediaType; // 'tv' | 'movie'
  final String title;

  const DiscoverGridScreen({super.key, required this.mediaType, required this.title});

  @override
  State<DiscoverGridScreen> createState() => _DiscoverGridScreenState();
}

class _DiscoverGridScreenState extends State<DiscoverGridScreen> {
  final _scrollController = ScrollController();
  final List<SimilarMedia> _items = [];
  int _nextPage = 1;
  bool _loading = false;
  bool _exhausted = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final tmdb = context.read<TmdbService>();
      final results = await tmdb.discoverMedia(
        mediaType: widget.mediaType,
        page: _nextPage,
        sortBy: 'popularity.desc',
      );
      if (results.isEmpty) {
        _exhausted = true;
      } else {
        _nextPage++;
        _items.addAll(results);
      }
    } catch (_) {
      if (_items.isEmpty) _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final tmdb = context.read<TmdbService>();
      final results = await tmdb.discoverMedia(
        mediaType: widget.mediaType,
        page: 1,
        sortBy: 'popularity.desc',
      );
      if (!mounted) return;
      setState(() {
        final existingIds = _items.map((m) => m.id).toSet();
        final newOnes = results.where((m) => !existingIds.contains(m.id)).toList();
        _items.insertAll(0, newOnes);
      });
    } catch (_) {
      // Pull-to-refresh failing quietly just means the user can try again.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _items.isEmpty
            ? (_loading
                ? const PosterGridSkeleton(childAspectRatio: 0.67)
                : ScrollableCenter(
                    child: _error
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Impossible de charger.',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _loadMore, child: const Text('Réessayer')),
                            ],
                          )
                        : const Text('Aucun résultat.'),
                  ))
            : GridView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.67,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) => FadeInEntry(
                  index: index,
                  child: DiscoverPosterTile(
                    media: _items[index],
                    showFollowBadge: false,
                    heroTag: posterHeroTag(_items[index].type, _items[index].id),
                  ),
                ),
              ),
      ),
    );
  }
}
