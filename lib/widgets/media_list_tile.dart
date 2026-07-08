import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../theme/app_theme.dart';

class MediaListTile extends StatelessWidget {
  final String? posterPath;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? heroTag;

  const MediaListTile({
    super.key,
    required this.posterPath,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 78,
                child: _poster(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }

  Widget _poster() {
    final image = posterPath != null
        ? CachedNetworkImage(
            imageUrl: '${TmdbConfig.imageBaseUrlTiny}$posterPath',
            fit: BoxFit.cover,
          )
        : Container(
            color: AppColors.surfaceVariant,
            child: const Icon(Icons.tv, color: AppColors.textSecondary),
          );
    return heroTag != null ? Hero(tag: heroTag!, child: image) : image;
  }
}
