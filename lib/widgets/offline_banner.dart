import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Slim bar shown at the top of the app while offline, so a watched-toggle
/// or a stat that doesn't update yet reads as "queued until reconnected"
/// rather than "broken".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: const [
            SizedBox(width: 12),
            Icon(Icons.cloud_off, size: 14, color: Colors.black),
            SizedBox(width: 6),
            Expanded(
              child: _MarqueeText(
                'Hors ligne — les changements seront synchronisés au retour de la connexion',
              ),
            ),
            SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Scrolls its text horizontally in a seamless loop — the banner's message
/// is too long to fit on a phone-width bar without wrapping to several
/// lines, and a ticker reads better here than a taller multi-line banner.
class _MarqueeText extends StatefulWidget {
  final String text;

  const _MarqueeText(this.text);

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  static const _style = TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700);
  static const _gap = 48.0; // space between the two looping copies of the text
  static const _pixelsPerSecond = 40.0;

  late final AnimationController _controller;
  late final double _textWidth;

  @override
  void initState() {
    super.initState();
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _style),
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = painter.width;
    final loopDistance = _textWidth + _gap;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (loopDistance / _pixelsPerSecond * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final dx = -_controller.value * (_textWidth + _gap);
            return Stack(
              children: [
                Positioned(
                  left: dx,
                  top: 0,
                  bottom: 0,
                  // Positioned with only `left` set gives its child unbounded
                  // width constraints; Row defaults to mainAxisSize.max, which
                  // throws under an unbounded width — happening on every
                  // single animation frame, which is exactly what flooded the
                  // console. mainAxisSize.min sizes it to its children instead.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.text, style: _style, maxLines: 1, softWrap: false),
                      const SizedBox(width: _gap),
                      Text(widget.text, style: _style, maxLines: 1, softWrap: false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
