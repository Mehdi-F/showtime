import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';

class PosterTile extends StatelessWidget {
  final String? posterPath;
  final String title;
  final VoidCallback? onTap;
  final Widget? overlay;

  const PosterTile({
    super.key,
    required this.posterPath,
    required this.title,
    this.onTap,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey[800], child: const Icon(Icons.tv)),
                ),
                ?overlay,
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
