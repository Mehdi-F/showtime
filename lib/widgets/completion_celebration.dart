import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/tmdb_config.dart';
import '../l10n/localization_context.dart';
import '../theme/app_theme.dart';

/// Celebration shown once a series is finished for good: a badge that springs
/// in over an expanding ring and a bloom of gold particles.
///
/// Replaces the generic multicolour confetti burst — same moment, but built
/// from the app's own accent palette so it reads as Showtime rather than as a
/// party popper, and short enough not to sit in the way of the page.
class CompletionCelebration extends StatelessWidget {
  final AnimationController controller;

  /// The finished show's poster, shown in the medallion. Falls back to a
  /// check mark when TMDB has no poster for the title.
  final String? posterPath;

  const CompletionCelebration({
    super.key,
    required this.controller,
    this.posterPath,
  });

  static final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    // Fixed seed: the burst should look designed, not different every time.
    final random = Random(20260927);
    return List.generate(22, (i) {
      final angle = (i / 22) * 2 * pi + random.nextDouble() * 0.28;
      return _Particle(
        angle: angle,
        distance: 90 + random.nextDouble() * 80,
        size: 2 + random.nextDouble() * 3.5,
        delay: random.nextDouble() * 0.12,
        shade: random.nextDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          if (t == 0) return const SizedBox.shrink();

          final fadeOut = 1 - Curves.easeIn.transform(
            ((t - 0.82) / 0.18).clamp(0.0, 1.0),
          );
          final badgeScale = Curves.elasticOut.transform(
            (t / 0.55).clamp(0.0, 1.0),
          );
          final labelOpacity =
              Curves.easeOut.transform(((t - 0.22) / 0.25).clamp(0.0, 1.0));

          return Opacity(
            opacity: fadeOut,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BloomPainter(progress: t, particles: _particles),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: badgeScale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          // White on dark, black on light: the medallion has
                          // to read against both the page and whatever the
                          // poster's edges happen to be.
                          border: Border.all(color: context.colorTextPrimary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: '${TmdbConfig.imageBaseUrlSmall}$posterPath',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 46,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, color: Colors.black, size: 46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: labelOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            context.tr('celebrate.seriesCompleted'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  /// 0 → accent, 1 → a paler gold, so the bloom has depth without leaving
  /// the palette.
  final double shade;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.shade,
  });
}

class _BloomPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _BloomPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Two staggered rings read as a single pulse with depth.
    for (var i = 0; i < 2; i++) {
      final ringT = ((progress - i * 0.09) / 0.6).clamp(0.0, 1.0);
      if (ringT <= 0 || ringT >= 1) continue;
      final eased = Curves.easeOutCubic.transform(ringT);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - eased) + 0.5
        ..color = AppColors.accent.withValues(alpha: (1 - eased) * 0.7);
      canvas.drawCircle(center, 30 + eased * 130, paint);
    }

    for (final p in particles) {
      final pt = ((progress - p.delay) / (0.85 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;
      final eased = Curves.easeOutCubic.transform(pt);
      final radius = 26 + eased * p.distance;
      // A touch of gravity so the bloom settles instead of floating away.
      final drop = 34 * pt * pt;
      final offset = Offset(
        center.dx + cos(p.angle) * radius,
        center.dy + sin(p.angle) * radius + drop,
      );
      final paint = Paint()
        ..color = Color.lerp(AppColors.accent, const Color(0xFFFFE9A8), p.shade)!
            .withValues(alpha: (1 - pt * pt).clamp(0.0, 1.0));
      canvas.drawCircle(offset, p.size * (1 - pt * 0.45), paint);
    }
  }

  @override
  bool shouldRepaint(_BloomPainter oldDelegate) => oldDelegate.progress != progress;
}
