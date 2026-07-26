import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../motion.dart';

/// Smoothly animates an integer (a balance) from its previous value to a new
/// one, rendering each interpolated step through [format]. Counts up from zero
/// the first time it appears.
///
/// Pair with a tabular-figure text style — without one, the digits change
/// width as they tick and the whole number jitters sideways.
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
      // Decelerating: the number sprints then eases into its final value,
      // which reads as "settling" rather than "scrolling".
      curve: Motion.enter,
      builder: (context, v, _) => Text(
        format(v.round()),
        style: (style ?? const TextStyle())
            .copyWith(fontFeatures: kTabularFigures),
      ),
    );
  }
}
