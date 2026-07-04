import 'package:flutter/material.dart';

/// A centered widget wrapped in a scrollable so a [RefreshIndicator] ancestor
/// can still be pulled down even when the content is shorter than the
/// viewport (loading/empty states).
class ScrollableCenter extends StatelessWidget {
  final Widget child;

  const ScrollableCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Center(child: child),
        ),
      ],
    );
  }
}
