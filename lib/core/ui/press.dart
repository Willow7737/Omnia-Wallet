import 'package:flutter/material.dart';

import '../haptics.dart';
import '../motion.dart';

/// How firmly a surface responds to a press.
enum PressFeel {
  /// Opacity only. For text links and icon buttons, where scaling a small
  /// target reads as a glitch.
  subtle,

  /// Opacity + a light scale. The default for rows, cards and tiles.
  normal,

  /// A deeper scale. For big, standalone targets — primary buttons, the
  /// balance card.
  firm,

  /// No visual change at all (the child animates itself).
  none,
}

/// The app's single press primitive.
///
/// React Native's `Pressable` responds with **opacity and scale**, not with
/// Material's expanding ink ripple, and that difference is most of why RN apps
/// feel physical where Material apps feel inked. Ripples are disabled app-wide
/// in the theme; this widget provides the replacement.
///
/// The haptic fires on **touch-down**, not on tap-up. Perceived latency is
/// dominated by when the feedback lands, not when the navigation does, so
/// waiting for the tap to complete makes the whole app feel slower even though
/// nothing changed.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.feel = PressFeel.normal,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final PressFeel feel;
  final bool haptic;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  double get _scale => switch (widget.feel) {
        PressFeel.subtle => 1.0,
        PressFeel.normal => 0.98,
        PressFeel.firm => 0.965,
        PressFeel.none => 1.0,
      };

  double get _opacity => switch (widget.feel) {
        PressFeel.none => 1.0,
        _ => 0.6,
      };

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _down ? _scale : 1.0,
      duration: Motion.micro,
      curve: Motion.standard,
      child: AnimatedOpacity(
        opacity: _down ? _opacity : 1.0,
        duration: Motion.micro,
        curve: Motion.standard,
        child: widget.child,
      ),
    );

    if (widget.semanticLabel != null) {
      child = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _enabled
          ? (_) {
              _set(true);
              // Fire immediately — see the class doc.
              if (widget.haptic) Haptics.light();
            }
          : null,
      onTapUp: _enabled ? (_) => _set(false) : null,
      onTapCancel: _enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) Haptics.medium();
              widget.onLongPress!();
            },
      child: child,
    );
  }
}
