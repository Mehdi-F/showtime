import 'package:flutter/material.dart';

/// Drop-in replacement for [MaterialPageRoute] with a softer transition — the
/// incoming page fades in while easing up slightly instead of the abrupt
/// platform slide, giving every push in the app the same fluid feel.
Route<T> appRoute<T>({required WidgetBuilder builder, bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic, parent: animation);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
