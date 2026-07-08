import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';

/// A horizontally-scrolling strip of actual scene shots (backdrops) for a
/// show/movie — tapping any thumbnail opens the full gallery in a
/// swipeable, zoomable full-screen viewer.
class ImageGalleryRow extends StatelessWidget {
  final Future<TitleImages> future;
  static const _maxPhotos = 20;

  const ImageGalleryRow({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TitleImages>(
      future: future,
      builder: (context, snapshot) {
        final images = snapshot.data;
        if (images == null) return const SizedBox.shrink();
        // Posters are mostly redundant promotional art repeated per
        // language/region (which is why the row felt overwhelming) — only
        // fall back to them if a title has no backdrops (actual scenes) at
        // all, and cap the total so it stays a quick scroll either way.
        final source = images.backdropPaths.isNotEmpty ? images.backdropPaths : images.posterPaths;
        final paths = source.take(_maxPhotos).toList();
        if (paths.isEmpty) return const SizedBox.shrink();
        final backdropCount = images.backdropPaths.isNotEmpty ? paths.length : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Photos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: paths.length,
                itemBuilder: (context, index) {
                  final isBackdrop = index < backdropCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => showImageGalleryViewer(context, paths: paths, initialIndex: index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: '${TmdbConfig.imageBaseUrl}${paths[index]}',
                          fit: BoxFit.cover,
                          width: isBackdrop ? 160 : 64,
                          height: 90,
                        ),
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

void showImageGalleryViewer(BuildContext context, {required List<String> paths, required int initialIndex}) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
      opacity: animation,
      child: _ImageGalleryViewer(paths: paths, initialIndex: initialIndex),
    ),
  ));
}

class _ImageGalleryViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImageGalleryViewer({required this.paths, required this.initialIndex});

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: '${TmdbConfig.imageBaseUrl}${widget.paths[index]}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (widget.paths.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Text(
                    '${_index + 1} / ${widget.paths.length}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
