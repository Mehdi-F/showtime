import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';
import '../theme/app_theme.dart';

class WatchProvidersRow extends StatelessWidget {
  final Future<List<WatchProvider>> future;

  const WatchProvidersRow({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WatchProvider>>(
      future: future,
      builder: (context, snapshot) {
        final providers = snapshot.data ?? const [];
        if (providers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Où regarder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.logoPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: '${TmdbConfig.imageBaseUrl}${provider.logoPath}',
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(provider.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  final String? yearRange;
  final List<String> genres;
  final double voteAverage;
  final String overview;
  final int runtimeMinutes;
  final String addedCaption;

  const InfoCard({
    super.key,
    required this.yearRange,
    required this.genres,
    required this.voteAverage,
    required this.overview,
    required this.runtimeMinutes,
    required this.addedCaption,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (yearRange != null) yearRange!,
      if (genres.isNotEmpty) genres.join(', '),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 10),
          if (subtitleParts.isNotEmpty)
            Text(subtitleParts.join(' • '),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (voteAverage > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text('${(voteAverage / 2).toStringAsFixed(1)}/5',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          if (overview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(overview, style: const TextStyle(fontSize: 14, height: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (runtimeMinutes > 0) ...[
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('$runtimeMinutes min',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 16),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(addedCaption, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Divider(height: 1),
          ),
        ],
      ),
    );
  }
}

class CastRow extends StatelessWidget {
  final Future<List<CastMember>> future;

  const CastRow({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CastMember>>(
      future: future,
      builder: (context, snapshot) {
        final cast = snapshot.data ?? const [];
        if (cast.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Distribution', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: cast.length,
                itemBuilder: (context, index) {
                  final member = cast[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: member.profilePath != null
                                ? CachedNetworkImage(
                                    imageUrl: '${TmdbConfig.imageBaseUrl}${member.profilePath}',
                                    fit: BoxFit.cover,
                                    height: 100,
                                    width: 100,
                                  )
                                : Container(
                                    color: AppColors.surfaceVariant,
                                    height: 100,
                                    width: 100,
                                    child: const Icon(Icons.person, color: AppColors.textSecondary),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(member.character,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Divider(height: 1),
            ),
          ],
        );
      },
    );
  }
}

class SimilarRow extends StatelessWidget {
  final String title;
  final Future<List<SimilarMedia>> future;
  final void Function(SimilarMedia media) onTap;

  const SimilarRow({super.key, required this.title, required this.future, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SimilarMedia>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final media = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onTap(media),
                      child: SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: media.posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: '${TmdbConfig.imageBaseUrl}${media.posterPath}',
                                  fit: BoxFit.cover,
                                  height: 130,
                                  width: 90,
                                )
                              : Container(
                                  color: AppColors.surfaceVariant,
                                  height: 130,
                                  width: 90,
                                  child: const Icon(Icons.tv, color: AppColors.textSecondary),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
