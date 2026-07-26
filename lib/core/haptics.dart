import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic haptic feedback.
///
/// Call these by *intent* (`success`, `warning`, `tick`) rather than by
/// physical pattern, so the feel stays consistent and can be retuned in one
/// place.
///
/// Three rules are baked in here; all three come from the research in
/// `docs/DESIGN.md` §5.
///
/// 1. **Android clamps to light.** Bluesky ships
///    `const style = isIOS ? ImpactFeedbackStyle[strength] : Light` with the
///    comment *"users said the medium impact was too strong on Android"*.
///    Android's `mediumImpact` maps to a far heavier motor pulse than the iOS
///    taptic equivalent, and it is the main reason Flutter apps feel buzzy on
///    Android. [_impact] reproduces the clamp.
///
/// 2. **Micro-haptics are rate-limited.** A selection tick fired per frame
///    while a PageView settles, or per keystroke in an amount field, becomes a
///    continuous buzz. [tick] enforces a [_tickInterval] floor.
///
/// 3. **Compound patterns need real gaps.** Two impacts fired back to back
///    read as one smeared pulse. 90 ms is the floor at which two taps read as
///    two taps.
class Haptics {
  Haptics._();

  /// User preference, surfaced in Settings. Bluesky has the same switch.
  static bool enabled = true;

  /// The shortest gap between two [tick]s. Below this the motor never fully
  /// settles and successive ticks blur into a hum.
  static const Duration _tickInterval = Duration(milliseconds: 40);

  /// Gap between pulses in a compound pattern.
  static const Duration _patternGap = Duration(milliseconds: 90);

  static DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get _supported {
    if (!enabled) return false;
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Android gets Light for *everything*, no matter what was asked for.
  static bool get _clampToLight => !kIsWeb && Platform.isAndroid;

  static void _impact(_Strength strength) {
    if (!_supported) return;
    final effective = _clampToLight ? _Strength.light : strength;
    switch (effective) {
      case _Strength.light:
        HapticFeedback.lightImpact();
      case _Strength.medium:
        HapticFeedback.mediumImpact();
      case _Strength.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  // ---- micro ----

  /// The smallest unit of feedback: crossing a segment, moving between pages,
  /// a value snapping. Rate-limited — safe to call from a scroll or drag
  /// callback.
  static void tick() {
    if (!_supported) return;
    final now = DateTime.now();
    if (now.difference(_lastTick) < _tickInterval) return;
    _lastTick = now;
    HapticFeedback.selectionClick();
  }

  /// Selection changed — picking an item, toggling, copying. Not throttled;
  /// use [tick] for anything that can fire repeatedly.
  static void selection() {
    if (!_supported) return;
    HapticFeedback.selectionClick();
  }

  /// A light tap. Every button press-down goes through here.
  static void light() => _impact(_Strength.light);

  /// Committing to something: opening a confirm sheet, launching the scanner.
  static void medium() => _impact(_Strength.medium);

  /// Reserved for genuinely weighty moments. Clamped to light on Android.
  static void heavy() => _impact(_Strength.heavy);

  // ---- outcomes ----

  /// A soft pulse then a firmer one — reads as "landed".
  static Future<void> success() async {
    if (!_supported) return;
    _impact(_Strength.light);
    await Future<void>.delayed(_patternGap);
    _impact(_Strength.medium);
  }

  /// Needs attention but isn't fatal.
  static Future<void> warning() async {
    if (!_supported) return;
    _impact(_Strength.medium);
    await Future<void>.delayed(_patternGap);
    _impact(_Strength.light);
  }

  /// A failure — rejected input, network error. Two equal firm pulses.
  static Future<void> error() async {
    if (!_supported) return;
    _impact(_Strength.heavy);
    await Future<void>.delayed(_patternGap + const Duration(milliseconds: 20));
    _impact(_Strength.heavy);
  }

  /// A surface arriving. One notch above a button press, so a sheet opening
  /// feels different from a control responding.
  static void sheetOpen() => _impact(_Strength.medium);

  /// A surface leaving. Deliberately lighter than [sheetOpen] — going away
  /// should always feel lighter than arriving.
  static void sheetClose() => _impact(_Strength.light);

  /// Pull-to-refresh crossed its trigger threshold.
  static void refresh() => _impact(_Strength.medium);
}

enum _Strength { light, medium, heavy }
