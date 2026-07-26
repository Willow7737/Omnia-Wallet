import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The app's motion language — one source of truth for durations and curves.
///
/// Bluesky's stack navigator uses the platform-native push (a horizontal slide
/// with the outgoing screen parallaxing behind it) and reserves cross-fades for
/// tab switches. Durations are short: past ~300 ms a tap response starts
/// reading as sluggish.
class Motion {
  Motion._();

  // ---- durations ----

  /// Press-state changes. Short enough that press and release both land
  /// inside the finger's own travel.
  static const Duration micro = Duration(milliseconds: 90);

  /// Chips, toggles, a sheet closing.
  static const Duration fast = Duration(milliseconds: 180);

  /// Page pushes, a sheet opening, expanding sections.
  static const Duration normal = Duration(milliseconds: 260);

  /// Hero moments.
  static const Duration slow = Duration(milliseconds: 420);

  /// Balance count-up.
  static const Duration count = Duration(milliseconds: 700);

  // ---- curves ----

  /// Entrances: fast out of the gate, long settle. Material's "emphasized
  /// decelerate", which sits very close to iOS's push curve.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Exits: leaves quickly, no lingering settle.
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Everything two-directional.
  static const Curve standard = Curves.easeOutCubic;

  /// A touch of overshoot — used sparingly, for arrival moments only.
  static const Curve springy = Cubic(0.34, 1.4, 0.64, 1.0);

  /// Kept under its old name so existing call sites keep compiling.
  static const Curve emphasized = enter;
}

/// The shared push transition: the incoming screen slides in from the trailing
/// edge while the outgoing one parallaxes a third of the way out and dims.
/// This is what makes a stack read as a *stack* rather than a slideshow.
Page<T> pushPage<T>({
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
      final incoming = CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      );
      final outgoing = CurvedAnimation(
        parent: secondary,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      );

      return SlideTransition(
        // The screen underneath drifts a third of the way out and back.
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.28, 0),
        ).animate(outgoing),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.55).animate(outgoing),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(incoming),
            child: child,
          ),
        ),
      );
    },
  );
}

/// A pure cross-fade with no travel — for switching between peers (tabs),
/// where horizontal motion would imply a hierarchy that isn't there.
Page<T> fadePage<T>({
  required Widget child,
  required LocalKey key,
  required String name,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    transitionDuration: Motion.fast,
    reverseTransitionDuration: Motion.fast,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.standard),
      child: child,
    ),
  );
}

/// A screen that rises from the bottom edge — for the scanner and other
/// full-screen modal takeovers.
Page<T> modalPage<T>({
  required Widget child,
  required LocalKey key,
  required String name,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    transitionDuration: Motion.normal,
    reverseTransitionDuration: Motion.fast,
    fullscreenDialog: true,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      )),
      child: child,
    ),
  );
}

/// Retained under its old name so existing route definitions keep compiling.
Page<T> fadeThroughPage<T>({
  required Widget child,
  required LocalKey key,
  required String name,
}) =>
    pushPage<T>(child: child, key: key, name: name);
