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

String formatFrDate(DateTime date) => '${date.day} ${_frMonths[date.month - 1]} ${date.year}';

Future<void> showEpisodeDetailSheet(
  BuildContext context, {
  required EpisodeRef episode,
  required bool watched,
  required VoidCallback onToggleWatched,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) =>
        _EpisodeDetailSheet(episode: episode, watched: watched, onToggleWatched: onToggleWatched),
  );
}

class _EpisodeDetailSheet extends StatefulWidget {
  final EpisodeRef episode;
  final bool watched;
  final VoidCallback onToggleWatched;

  const _EpisodeDetailSheet({
    required this.episode,
    required this.watched,
    required this.onToggleWatched,
  });

  @override
  State<_EpisodeDetailSheet> createState() => _EpisodeDetailSheetState();
}

class _EpisodeDetailSheetState extends State<_EpisodeDetailSheet> {
  late bool _watched = widget.watched;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ep.stillPath != null
                        ? CachedNetworkImage(
                            imageUrl: '${TmdbConfig.imageBaseUrl}${ep.stillPath}',
                            fit: BoxFit.cover,
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
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                            Text(ep.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() => _watched = !_watched);
                          widget.onToggleWatched();
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: _watched ? Colors.green : AppColors.surfaceVariant,
                          child: Icon(Icons.check,
                              color: _watched ? Colors.white : AppColors.textSecondary),
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
              ),
            ),
          ],
        );
      },
    );
  }
}
