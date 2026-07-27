import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import 'url_builder.dart';

/// Returns a CachedNetworkImage with standard placeholder and error handling.
/// Uses a SkeletonBox while loading and a generic icon on failure.
Widget cachedImage({
  required String imageUrl,
  required BoxFit fit,
  double? width,
  double? height,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(6)),
  IconData errorIcon = Icons.image_not_supported,
}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    placeholder: (context, url) => SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
    ),
    errorWidget: (context, url, error) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: borderRadius,
      ),
      child: Icon(errorIcon, color: AppColors.textSecondary),
    ),
  );
}

/// Convenience wrapper for poster images (movie/TV show posters).
Widget cachedPosterImage({
  required String imageUrl,
  double? width,
  double? height,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(6)),
}) {
  return cachedImage(
    imageUrl: imageUrl,
    fit: BoxFit.cover,
    width: width,
    height: height,
    borderRadius: borderRadius,
    errorIcon: Icons.tv,
  );
}

/// Convenience wrapper for backdrop/banner images.
Widget cachedBackdropImage({
  required String imageUrl,
  double? width,
  double? height,
  BorderRadius borderRadius = BorderRadius.zero,
}) {
  return cachedImage(
    imageUrl: imageUrl,
    fit: BoxFit.cover,
    width: width,
    height: height,
    borderRadius: borderRadius,
    errorIcon: Icons.landscape,
  );
}

/// Convenience wrapper for cast/person photos.
Widget cachedPersonImage({
  required String imageUrl,
  double? width,
  double? height,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(6)),
}) {
  return cachedImage(
    imageUrl: imageUrl,
    fit: BoxFit.cover,
    width: width,
    height: height,
    borderRadius: borderRadius,
    errorIcon: Icons.person,
  );
}
