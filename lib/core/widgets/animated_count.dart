import 'package:flutter/material.dart';

import '../motion.dart';

/// Smoothly animates an integer value (e.g. a balance) from its previous value
/// to the new one, using [format] to render each interpolated step. Counts up
/// from zero the first time it appears.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.count,
  });

  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Motion.emphasized,
      builder: (context, v, _) => Text(format(v.round()), style: style),
    );
  }
}
