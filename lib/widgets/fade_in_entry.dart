import 'package:flutter/material.dart';

/// Wraps a lazily-built grid/list tile with a subtle fade + rise-in entrance,
/// staggered by [index] so items reveal progressively as they scroll into
/// view instead of popping in all at once. Purely a paint-time transform —
/// doesn't affect layout size or hit-testing once settled.
class FadeInEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const FadeInEntry({super.key, required this.index, required this.child});

  @override
  State<FadeInEntry> createState() => _FadeInEntryState();
}

class _FadeInEntryState extends State<FadeInEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_fade);

  @override
  void initState() {
    super.initState();
    // Capped so items far down a long grid don't sit waiting for ages.
    final delay = Duration(milliseconds: 20 * (widget.index % 12));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
