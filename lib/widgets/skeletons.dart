import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pulsing placeholder box — the base building block for every skeleton
/// loading state below, replacing bare spinners with a shape that hints at
/// the real content about to appear instead of a blank wait.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _opacity =
      Tween(begin: 0.4, end: 0.8).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: _opacity.value),
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// A 3-column grid of poster-shaped skeleton boxes, matching the grids it
/// stands in for (Films, Series, Explorer's browse-all, profile lists).
class PosterGridSkeleton extends StatelessWidget {
  final double childAspectRatio;
  final int itemCount;
  final bool shrinkWrap;

  const PosterGridSkeleton({
    super.key,
    this.childAspectRatio = 0.67,
    this.itemCount = 9,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonBox(borderRadius: BorderRadius.zero),
    );
  }
}

/// Mimics a detail screen's banner + info block while the real data loads.
class DetailScreenSkeleton extends StatelessWidget {
  const DetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final lineWidth = MediaQuery.of(context).size.width - 32;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(height: 220, borderRadius: BorderRadius.zero),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 180, height: 20),
              const SizedBox(height: 14),
              SkeletonBox(width: lineWidth, height: 13),
              const SizedBox(height: 8),
              SkeletonBox(width: lineWidth * 0.7, height: 13),
              const SizedBox(height: 8),
              const SkeletonBox(width: 140, height: 13),
            ],
          ),
        ),
      ],
    );
  }
}

/// A vertical list of poster-thumbnail + two-line-text rows, for search
/// results and other media lists while they load.
class MediaListSkeleton extends StatelessWidget {
  final int itemCount;

  const MediaListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SkeletonBox(width: 46, height: 66),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SkeletonBox(width: 160, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A handful of thin skeleton rows, for the moment between expanding a
/// season and its episode list actually being ready.
class EpisodeRowsSkeleton extends StatelessWidget {
  final int itemCount;

  const EpisodeRowsSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SkeletonBox(width: 64, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SkeletonBox(width: 140, height: 13),
                    SizedBox(height: 6),
                    SkeletonBox(width: 90, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mimics ProfileScreen's/FriendProfileScreen's header + stats + carousel
/// layout while the library is still resolving.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        const SkeletonBox(height: 160, borderRadius: BorderRadius.zero),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SkeletonBox(width: 60, height: 36),
              SkeletonBox(width: 60, height: 36),
              SkeletonBox(width: 60, height: 36),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (var row = 0; row < 2; row++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonBox(width: 100, height: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SkeletonBox(width: 90, height: 130),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
