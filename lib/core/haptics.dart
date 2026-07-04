import 'package:flutter/services.dart';

/// Semantic haptic feedback. Call these by *intent* (success, warning, …)
/// rather than by physical pattern, so the feel stays consistent and can be
/// tuned in one place.
class Haptics {
  Haptics._();

  /// A light tap — button presses, toggles.
  static void light() => HapticFeedback.lightImpact();

  /// A medium tap — committing an action (opening scanner, confirm sheet).
  static void medium() => HapticFeedback.mediumImpact();

  /// Selection tick — moving between items, copying.
  static void selection() => HapticFeedback.selectionClick();

  /// Positive outcome — a send completed. A soft then firmer double-tap.
  static Future<void> success() async {
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.mediumImpact();
  }

  /// Something needs attention but isn't fatal.
  static void warning() => HapticFeedback.mediumImpact();

  /// A failure — rejected input, network error.
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
  }
}
