import 'package:flutter/material.dart';

/// Fade in widget with configurable duration and curve
class FadeInWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const FadeInWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeIn,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

/// Slide out + fade animation for disappearing elements
class SlideOutFadeWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onAnimationComplete;
  final Duration duration;
  final Offset offset;

  const SlideOutFadeWidget({
    super.key,
    required this.child,
    required this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 300),
    this.offset = const Offset(0, 1),
  });

  @override
  State<SlideOutFadeWidget> createState() => _SlideOutFadeWidgetState();
}

class _SlideOutFadeWidgetState extends State<SlideOutFadeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _controller.forward().then((_) => widget.onAnimationComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: widget.offset).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInCubic),
      ),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInCubic),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Expand/collapse animation with size change
class ExpandCollapseWidget extends StatefulWidget {
  final bool isExpanded;
  final Widget child;
  final Duration duration;

  const ExpandCollapseWidget({
    super.key,
    required this.isExpanded,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<ExpandCollapseWidget> createState() => _ExpandCollapseWidgetState();
}

class _ExpandCollapseWidgetState extends State<ExpandCollapseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ExpandCollapseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      ),
      child: FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Cross fade between two widgets
class AnimatedViewSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedViewSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[...previousChildren, if (currentChild != null) currentChild],
        );
      },
      child: child,
    );
  }
}

/// Scale up fade animation for appearing elements
class ScaleFadeWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginScale;

  const ScaleFadeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
    this.beginScale = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: beginScale, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, scaleValue, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: duration,
          curve: curve,
          builder: (context, opacityValue, _) {
            return Opacity(
              opacity: opacityValue,
              child: Transform.scale(scale: scaleValue, child: child),
            );
          },
        );
      },
      child: child,
    );
  }
}

/// Animated button state transition (text to loading spinner)
class AnimatedButtonState extends StatefulWidget {
  final bool isLoading;
  final Widget normalChild;
  final Widget? loadingChild;
  final Duration duration;

  const AnimatedButtonState({
    super.key,
    required this.isLoading,
    required this.normalChild,
    this.loadingChild,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<AnimatedButtonState> createState() => _AnimatedButtonStateState();
}

class _AnimatedButtonStateState extends State<AnimatedButtonState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    if (widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedButtonState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.0).animate(_controller),
          child: widget.normalChild,
        ),
        FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(_controller),
          child: widget.loadingChild ?? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ],
    );
  }
}

/// Rotate animation (for expand/collapse arrows, etc)
class RotateWidget extends StatelessWidget {
  final bool isRotated;
  final Widget child;
  final Duration duration;
  final double angle; // in radians, default 180 degrees = pi

  const RotateWidget({
    super.key,
    required this.isRotated,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.angle = 3.14159, // pi radians = 180 degrees
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isRotated ? angle : 0),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) => Transform.rotate(angle: value, child: child),
      child: child,
    );
  }
}

/// Bounce scale animation for emphasis
class BounceWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const BounceWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.05),
      duration: duration ~/ 2,
      curve: Curves.elasticIn,
      builder: (context, value, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.05, end: 1.0),
          duration: duration ~/ 2,
          curve: Curves.elasticOut,
          builder: (context, value2, _) => Transform.scale(scale: value2, child: child),
          child: Transform.scale(scale: value, child: child),
        );
      },
    );
  }
}
