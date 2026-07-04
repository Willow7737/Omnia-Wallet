import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Central motion language — one source of truth for durations and curves so
/// every transition in the app feels like it belongs to the same system.
class Motion {
  Motion._();

  // Durations
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration count = Duration(milliseconds: 900);

  // Curves — emphasized easing for entrances, standard for the rest.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve springy = Curves.easeOutBack;
}

/// A shared page transition: a soft fade combined with a small upward slide.
/// Used for all pushed routes so navigation feels cohesive.
Page<T> fadeThroughPage<T>({
  required Widget child,
  required LocalKey key,
  required String name,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    transitionDuration: Motion.normal,
    reverseTransitionDuration: Motion.fast,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasized,
        reverseCurve: Motion.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
