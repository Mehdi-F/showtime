import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../l10n/localization_context.dart';
import '../widgets/discover_poster_tile.dart';
import '../widgets/fade_in_entry.dart';
import '../widgets/poster_hero_tag.dart';
import '../widgets/scrollable_center.dart';
import '../widgets/skeletons.dart';

/// Full paginated browse grid over any TMDB list endpoint (general discover,
/// trending, popular, top rated...) for a media type. Reached from the
/// Explorer "Séries"/"Films" pills and each category row's chevron.
class DiscoverGridScreen extends StatefulWidget {
  final String mediaType; // 'tv' | 'movie'
  final String title;
  final Future<List<SimilarMedia>> Function(int page)? fetchPage;

  // Ranked lists like "trending" or "top rated" only stay relevant for a
  // handful of pages — past that TMDB is essentially padding with noise, so
  // those categories cap how far the infinite scroll goes. The general
  // "all series/films" catalog (fetchPage null, or discover by popularity)
  // has no such relevance cliff and stays uncapped.
  final int? maxPages;

  const DiscoverGridScreen({
    super.key,
    required this.mediaType,
    required this.title,
    this.fetchPage,
    this.maxPages,
  });

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

  Future<List<SimilarMedia>> _fetch(int page) {
    if (widget.fetchPage != null) return widget.fetchPage!(page);
    return context.read<TmdbService>().discoverMedia(
          mediaType: widget.mediaType,
          page: page,
          sortBy: 'popularity.desc',
        );
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    if (widget.maxPages != null && _nextPage > widget.maxPages!) {
      setState(() => _exhausted = true);
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await _fetch(_nextPage);
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
      final results = await _fetch(1);
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
    // Already-watched titles just add clutter to a "what should I watch
    // next" browse list, so they're hidden here (the library itself, where
    // you'd go to revisit something, still shows everything).
    final watchedTmdbIds = widget.mediaType != 'movie'
        ? const <int>{}
        : context
            .watch<LibraryProvider>()
            .items
            .where((i) => i.type == 'movie' && i.watched)
            .map((i) => i.tmdbId)
            .toSet();
    final visibleItems = watchedTmdbIds.isEmpty
        ? _items
        : _items.where((m) => !watchedTmdbIds.contains(m.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: visibleItems.isEmpty
            ? (_loading
                ? const PosterGridSkeleton(childAspectRatio: 0.67)
                : ScrollableCenter(
                    child: _error
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.tr('empty.loadFailed'),
                                  style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _loadMore, child: Text(context.tr('common.retry'))),
                            ],
                          )
                        : Text(context.tr('empty.noResults')),
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
                itemCount: visibleItems.length,
                itemBuilder: (context, index) => FadeInEntry(
                  index: index,
                  child: DiscoverPosterTile(
                    media: visibleItems[index],
                    showFollowBadge: false,
                    heroTag: posterHeroTag(visibleItems[index].type, visibleItems[index].id),
                  ),
                ),
              ),
      ),
    );
  }
}
