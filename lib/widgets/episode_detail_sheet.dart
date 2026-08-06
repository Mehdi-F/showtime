import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';
import '../theme/app_theme.dart';
import './animations.dart';

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

String formatFrDate(DateTime date) => '${date.day} ${_frMonths[date.month - 1]} ${date.year}';

Future<void> showEpisodeDetailSheet(
  BuildContext context, {
  required List<EpisodeRef> episodes,
  required int initialIndex,
  required Map<String, bool> watchedMap,
  required Function(EpisodeRef, bool) onToggleWatched,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
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
  late PageController _pageController;
  late ScrollController _dotsController;
  late int _currentIndex = widget.initialIndex;
  late Map<String, bool> _watchedMap = Map.from(widget.watchedMap);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _dotsController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDotsToCenter());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _scrollDotsToCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dotsController.hasClients) return;
      const dotSize = 18.0; // ~6 or 24 width + 12 margins
      final offset = (_currentIndex * dotSize) - (MediaQuery.of(context).size.width / 2 - 12);
      _dotsController.animateTo(
        offset.clamp(0.0, _dotsController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
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
            // PageView for swiping between episodes
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _scrollDotsToCenter();
                },
                itemCount: widget.episodes.length,
                itemBuilder: (context, index) {
                  final ep = widget.episodes[index];
                  return _EpisodeImageCard(episode: ep);
                },
              ),
            ),
            // Page indicator dots with scroll effect
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: const [0, 0.1, 0.9, 1],
                ).createShader(bounds),
                child: SingleChildScrollView(
                  controller: _dotsController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.episodes.length,
                      (index) {
                        final isActive = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: isActive ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _EpisodeInfo(
                    episode: widget.episodes[_currentIndex],
                    watched: _watchedMap[widget.episodes[_currentIndex].key] ?? false,
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: episode.stillPath != null
                ? CachedNetworkImage(
                    imageUrl: '${TmdbConfig.imageBaseUrlSmall}${episode.stillPath}',
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.tv, color: AppColors.textSecondary, size: 40),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.tv, color: AppColors.textSecondary, size: 40),
                  ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ),
            ),
          ),
        ],
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
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(ep.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                  backgroundColor: _watched ? Colors.green : AppColors.surfaceVariant,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      Icons.check,
                      key: ValueKey(_watched),
                      color: _watched ? Colors.white : AppColors.textSecondary,
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
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(formatFrDate(ep.airDate!),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ],
        const Divider(height: 32),
        const Text('SYNOPSIS',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(
          ep.overview.isNotEmpty ? ep.overview : 'Aucun synopsis disponible.',
          style: const TextStyle(height: 1.4),
        ),
      ],
    );
  }
}
