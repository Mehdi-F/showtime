import 'package:flutter/material.dart';

/// A width-fraction bar that eases toward [value] instead of snapping, so a
/// watched-count change reads as a fluid fill rather than a jump cut.
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) => Container(
        height: height,
        color: backgroundColor,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: animatedValue,
          child: Container(color: color),
        ),
      ),
    );
  }
}
