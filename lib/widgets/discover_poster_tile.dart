import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../screens/show_detail_screen.dart';
import '../screens/movie_detail_screen.dart';

/// A poster tile for browsing TMDB's general catalog (not yet in the user's
/// library). Tapping the poster opens a preview of its detail screen without
/// following it; tapping the badge follows it without navigating away.
class DiscoverPosterTile extends StatelessWidget {
  final SimilarMedia media;
  final double? width;
  final double? height;
  final bool showFollowBadge;

  const DiscoverPosterTile({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.showFollowBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = context.watch<LibraryProvider>().items;
    LibraryItem? maybeExisting;
    for (final i in items) {
      if (i.tmdbId == media.id && i.type == media.type) maybeExisting = i;
    }
    final existing = maybeExisting;
    final followed = existing != null;

    Future<void> follow() async {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<LibraryService>().addToLibrary(uid: uid, tmdbId: media.id, type: media.type);
    }

    Future<void> unfollow() async {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<LibraryService>().removeFromLibrary(uid: uid, tmdbId: media.id, type: media.type);
    }

    // Just viewing a title should never add it to the library — only the
    // follow badge (or an in-detail action) does that.
    void openDetail() {
      if (existing != null) {
        final item = existing;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              media.type == 'tv' ? ShowDetailScreen(libraryItem: item) : MovieDetailScreen(libraryItem: item),
        ));
      } else {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => media.type == 'tv'
              ? ShowDetailScreen.preview(tmdbId: media.id)
              : MovieDetailScreen.preview(tmdbId: media.id),
        ));
      }
    }

    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: media.posterPath != null
          ? CachedNetworkImage(
              imageUrl: '${TmdbConfig.imageBaseUrl}${media.posterPath}',
              fit: BoxFit.cover,
              width: width,
              height: height,
            )
          : Container(
              color: AppColors.surfaceVariant,
              width: width,
              height: height,
              child: Icon(media.type == 'tv' ? Icons.tv : Icons.movie, color: AppColors.textSecondary),
            ),
    );

    return GestureDetector(
      onTap: openDetail,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: width == null ? StackFit.expand : StackFit.loose,
          children: [
            poster,
            if (showFollowBadge)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: followed ? unfollow : follow,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: followed ? AppColors.accent : Colors.black54,
                      border: Border.all(color: AppColors.accent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(followed ? Icons.check : Icons.add,
                        color: followed ? Colors.black : AppColors.accent, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
