import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';
import '../theme/app_theme.dart';

const _frMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatFrDate(DateTime date) =>
    '${date.day} ${_frMonths[date.month - 1]} ${date.year}';

Future<void> showEpisodeDetailSheet(
  BuildContext context, {
  required List<EpisodeRef> episodes,
  required int initialIndex,
  required Map<String, bool> watchedMap,
  required Function(EpisodeRef, bool) onToggleWatched,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.colorSurface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _EpisodeDetailSheet(
      episodes: episodes,
      initialIndex: initialIndex,
      watchedMap: watchedMap,
      onToggleWatched: onToggleWatched,
    ),
  );
}

class _EpisodeDetailSheet extends StatefulWidget {
  final List<EpisodeRef> episodes;
  final int initialIndex;
  final Map<String, bool> watchedMap;
  final Function(EpisodeRef, bool) onToggleWatched;

  const _EpisodeDetailSheet({
    required this.episodes,
    required this.initialIndex,
    required this.watchedMap,
    required this.onToggleWatched,
  });

  @override
  State<_EpisodeDetailSheet> createState() => _EpisodeDetailSheetState();
}

class _EpisodeDetailSheetState extends State<_EpisodeDetailSheet> {
  // Leaves the neighbouring episodes peeking at the edges, which is what
  // tells you the row can be swiped at all — the old full-bleed pages gave
  // no such hint.
  static const _viewportFraction = 0.86;

  late PageController _pageController;
  late int _currentIndex = widget.initialIndex;
  late double _page = widget.initialIndex.toDouble();
  final Map<String, bool> _watchedMap = {};

  @override
  void initState() {
    super.initState();
    _watchedMap.addAll(widget.watchedMap);
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: _viewportFraction,
    );
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page != null && page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Fixed chrome: the close affordance used to live inside the
            // card, so it was rebuilt per page and slid around with it.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    color: context.colorTextSecondary,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${_currentIndex + 1}/${widget.episodes.length}',
                      style: TextStyle(
                        color: context.colorTextSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The card sizes itself from its own 16:9 ratio instead of a
            // fraction of screen height — the two used to fight, leaving a
            // gap on tall screens and cropping on short ones.
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth * _viewportFraction - 16;
                return SizedBox(
                  height: cardWidth * 9 / 16,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemCount: widget.episodes.length,
                    itemBuilder: (context, index) {
                      // Neighbours sit back slightly so the focused episode
                      // reads as the subject rather than one of three.
                      final distance = (_page - index).abs().clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: 1 - distance * 0.06,
                        child: Opacity(
                          opacity: 1 - distance * 0.35,
                          child: _EpisodeImageCard(episode: widget.episodes[index]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // A single thin bar beats one dot per episode: a 24-episode
            // season turned the old indicator into an unreadable row, and
            // its scroll-centring maths drifted because the dot width
            // changed with the active state.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = widget.episodes.length;
                  final width = count <= 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth / count).clamp(18.0, constraints.maxWidth);
                  final left = count <= 1
                      ? 0.0
                      : (constraints.maxWidth - width) * (_page / (count - 1)).clamp(0.0, 1.0);
                  return SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: context.colorSurfaceVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Positioned(
                          left: left,
                          child: Container(
                            width: width,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _EpisodeInfo(
                    episode: widget.episodes[_currentIndex],
                    watched:
                        _watchedMap[widget.episodes[_currentIndex].key] ??
                        false,
                    onToggleWatched: () {
                      final ep = widget.episodes[_currentIndex];
                      final newWatched = !(_watchedMap[ep.key] ?? false);
                      setState(() => _watchedMap[ep.key] = newWatched);
                      widget.onToggleWatched(ep, newWatched);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EpisodeImageCard extends StatelessWidget {
  final EpisodeRef episode;

  const _EpisodeImageCard({required this.episode});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: context.colorSurfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.tv, color: context.colorTextSecondary, size: 40),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (episode.stillPath != null)
              CachedNetworkImage(
                imageUrl: '${TmdbConfig.imageBaseUrlSmall}${episode.stillPath}',
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => Container(color: context.colorSurfaceVariant),
                errorWidget: (_, __, ___) => fallback,
              )
            else
              fallback,
            // Keeps the episode identifiable mid-swipe, when the details
            // below still belong to the previous page.
            Positioned(
              left: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'S${episode.seasonNumber.toString().padLeft(2, '0')}'
                    'E${episode.episodeNumber.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeInfo extends StatefulWidget {
  final EpisodeRef episode;
  final bool watched;
  final VoidCallback onToggleWatched;

  const _EpisodeInfo({
    required this.episode,
    required this.watched,
    required this.onToggleWatched,
  });

  @override
  State<_EpisodeInfo> createState() => _EpisodeInfoState();
}

class _EpisodeInfoState extends State<_EpisodeInfo> {
  late bool _watched;

  @override
  void initState() {
    super.initState();
    _watched = widget.watched;
  }

  @override
  void didUpdateWidget(covariant _EpisodeInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watched != widget.watched) {
      _watched = widget.watched;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'S${ep.seasonNumber.toString().padLeft(2, '0')} | E${ep.episodeNumber.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: context.colorTextSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ep.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() => _watched = !_watched);
                widget.onToggleWatched();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _watched
                      ? Colors.green
                      : context.colorSurfaceVariant,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      Icons.check,
                      key: ValueKey(_watched),
                      color: _watched ? Colors.white : context.colorTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (ep.airDate != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: context.colorTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                formatFrDate(ep.airDate!),
                style: TextStyle(color: context.colorTextSecondary),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        Text(
          'SYNOPSIS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: context.colorTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ep.overview.isNotEmpty ? ep.overview : 'Aucun synopsis disponible.',
          style: const TextStyle(height: 1.4),
        ),
      ],
    );
  }
}
