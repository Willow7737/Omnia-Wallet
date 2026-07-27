import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../haptics.dart';
import '../motion.dart';
import '../theme.dart';
import 'press.dart';

/// Wraps a scrollable and floats a "back to top" button once the reader has
/// gone far enough down that scrolling back would be a chore.
///
/// Two details make the difference between this feeling native and feeling
/// bolted on:
///
///  * It appears on **upward** movement only, past the threshold. Someone
///    still reading downward has not asked to leave; putting a button over
///    their content while they read is the behaviour people complain about.
///  * It rides on the scrollable it is given rather than a controller passed
///    in, so it works over a `ListView`, a `CustomScrollView`, or anything
///    else, with no plumbing at the call site.
class ScrollToTop extends StatefulWidget {
  const ScrollToTop({
    super.key,
    required this.child,
    this.screens = 1.0,
    this.minOffset = 400,
    this.bottomInset = 0,
    this.alignment = Alignment.bottomCenter,
  });

  final Widget child;

  /// How far down the button starts being offered, counted in screenfuls.
  ///
  /// Measured against the viewport rather than a fixed pixel count, because a
  /// fixed one means "far" depends on how tall the rows happen to be. A feed
  /// of tall posts passed 900px almost immediately while a log of short
  /// transaction rows never reached it at all — same gesture, same amount of
  /// reading, no button. One screenful is the point at which the top is off
  /// screen and staying there.
  final double screens;

  /// Floor for the above, so a short viewport still requires real scrolling.
  final double minOffset;

  /// Extra space to clear at the bottom (a tab bar, a composer).
  final double bottomInset;

  final Alignment alignment;

  @override
  State<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends State<ScrollToTop> {
  bool _visible = false;
  ScrollPosition? _position;

  /// Where the reader was at the last update, to tell up from down.
  double _lastOffset = 0;

  double _thresholdFor(ScrollMetrics metrics) => math.max(
        widget.minOffset,
        metrics.viewportDimension * widget.screens,
      );

  bool _handle(ScrollNotification notification) {
    // Nested horizontal scrollers (a tag strip, a carousel) must not drive
    // this.
    if (notification.metrics.axis != Axis.vertical) return false;

    final threshold = _thresholdFor(notification.metrics);

    if (notification is ScrollUpdateNotification) {
      final ctx = notification.context;
      if (ctx != null) _position = Scrollable.maybeOf(ctx)?.position;

      final offset = notification.metrics.pixels;
      final goingUp = offset < _lastOffset;
      _lastOffset = offset;

      final next = offset > threshold && goingUp;
      if (next != _visible) setState(() => _visible = next);
    }

    if (notification is ScrollEndNotification &&
        notification.metrics.pixels <= threshold &&
        _visible) {
      setState(() => _visible = false);
    }
    return false;
  }

  Future<void> _toTop() async {
    Haptics.selection();
    final position = _position;
    if (position == null) return;
    // Jumping most of the way first keeps the animation short from very deep
    // in a feed — a proportional scroll from 20,000px would either take
    // several seconds or blur past everything.
    if (position.pixels > 4000) position.jumpTo(3000);
    await position.animateTo(
      0,
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;

    return NotificationListener<ScrollNotification>(
      onNotification: _handle,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_visible,
              child: Align(
                alignment: widget.alignment,
                child: AnimatedSlide(
                  offset: _visible ? Offset.zero : const Offset(0, 0.6),
                  duration: Motion.normal,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: Motion.fast,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: widget.bottomInset + Space.lg,
                        left: Space.lg,
                        right: Space.lg,
                      ),
                      child: Pressable(
                        onTap: _toTop,
                        feel: PressFeel.firm,
                        semanticLabel: 'Scroll back to top',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg,
                            vertical: Space.sm + 1,
                          ),
                          decoration: BoxDecoration(
                            color: o.text,
                            borderRadius: Radii.rFull,
                            boxShadow: o.shadowSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.arrow_up_2_copy,
                                size: 15,
                                color: o.bg,
                              ),
                              const SizedBox(width: Space.xs + 2),
                              Text(
                                'Back to top',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: FontSizes.sm,
                                  fontWeight: Weights.semiBold,
                                  color: o.bg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
