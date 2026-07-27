/// The shared anatomy of a post and a reply, modelled on Threads.
///
/// A thread item is three columns of one row:
///
/// ```
/// ┌────────┬──────────────────────────────────────────┬───────┐
/// │ avatar │ name · time                              │  ···  │
/// │   │    │ body                                     │       │
/// │   │    │ ♡ n   💬 n   ↻ n   ➤                     │       │
/// │   ●    │ (rail continues to the next sibling)     │       │
/// └────────┴──────────────────────────────────────────┴───────┘
/// ```
///
/// The left rail — the hairline running down from the avatar — is what makes a
/// conversation read as one thread rather than a list of separate cards, and
/// it is the detail most implementations leave out.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../motion.dart';
import '../theme.dart';
import 'button.dart';
import 'press.dart';

/// A thread item's header: identity on the left, overflow pinned to the right.
///
/// The pinning is the whole point of this widget existing. The obvious
/// spelling —
///
/// ```dart
/// Row(children: [Flexible(name), Text(time), Spacer(), moreButton])
/// ```
///
/// — is wrong, and wrong in a way that looks plausible: `Flexible` and
/// `Spacer` both default to `flex: 1`, so they *split* the free space and the
/// button settles in the middle of the row instead of at its end. Giving the
/// identity block the only flex fixes it, and keeps the name ellipsising.
class ThreadHeader extends StatelessWidget {
  const ThreadHeader({
    super.key,
    required this.name,
    required this.timestamp,
    this.onMore,
    this.moreTooltip = 'More',
    this.nameStyle,
  });

  final String name;
  final String timestamp;
  final VoidCallback? onMore;
  final String moreTooltip;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle ?? theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: Space.xs + 2),
              Text(
                timestamp,
                style: theme.textTheme.labelSmall?.copyWith(color: o.textLow),
              ),
            ],
          ),
        ),
        if (onMore != null)
          OmniaIconButton(
            icon: Iconsax.more_copy,
            size: 18,
            box: 32,
            color: o.textLow,
            tooltip: moreTooltip,
            onTap: onMore,
          ),
      ],
    );
  }
}

/// One action under a thread item: a glyph, and its count when there is one.
///
/// Threads keeps these left-aligned and evenly spaced, with the count set
/// immediately beside its icon so the pair reads as a unit.
class ThreadAction extends StatelessWidget {
  const ThreadAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.count,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final int? count;
  final Color? color;

  /// Gap between one action and the next.
  static const double gap = Space.xxl;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final tint = color ?? o.textLow;

    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: count == null ? label : '$label, $count',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tint),
            if ((count ?? 0) > 0) ...[
              const SizedBox(width: Space.xs + 2),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: FontSizes.sm,
                  color: tint,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A toggling action — like, dislike — with the pop Threads gives it on the
/// way in.
///
/// The glyph swaps outline→filled when active, which is the state signal that
/// survives being colour-blind; the tint is the reinforcement, not the message.
class ThreadToggleAction extends StatefulWidget {
  const ThreadToggleAction({
    super.key,
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.count,
    this.activeColor,
  });

  final bool active;

  /// Outline cut, shown when inactive.
  final IconData icon;

  /// Filled cut, shown when active.
  final IconData activeIcon;

  final String label;
  final VoidCallback onTap;
  final int? count;
  final Color? activeColor;

  @override
  State<ThreadToggleAction> createState() => _ThreadToggleActionState();
}

class _ThreadToggleActionState extends State<ThreadToggleAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.fast,
    lowerBound: 1.0,
    upperBound: 1.35,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    // Only the *engaging* direction pops. Undoing with a flourish would
    // celebrate the wrong thing.
    if (!widget.active) {
      _c.forward(from: 1.0).then((_) {
        if (mounted) _c.reverse();
      });
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return ScaleTransition(
      scale: _c,
      child: ThreadAction(
        icon: widget.active ? widget.activeIcon : widget.icon,
        label: widget.label,
        count: widget.count,
        color: widget.active ? (widget.activeColor ?? o.like) : null,
        onTap: _tap,
      ),
    );
  }
}

/// The heart.
class ThreadLikeAction extends StatelessWidget {
  const ThreadLikeAction({
    super.key,
    required this.liked,
    required this.onTap,
    this.count,
  });

  final bool liked;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => ThreadToggleAction(
        active: liked,
        icon: Iconsax.heart_copy,
        activeIcon: Iconsax.heart,
        label: 'Like',
        count: count,
        onTap: onTap,
        activeColor: context.omnia.like,
      );
}

/// The counterpart to the heart.
///
/// Tinted with the *text* colour when active rather than a red — a dislike is
/// a quiet signal, and painting it as an alarm invites people to use it as
/// one.
class ThreadDislikeAction extends StatelessWidget {
  const ThreadDislikeAction({
    super.key,
    required this.disliked,
    required this.onTap,
    this.count,
  });

  final bool disliked;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => ThreadToggleAction(
        active: disliked,
        icon: Iconsax.dislike_copy,
        activeIcon: Iconsax.dislike,
        label: 'Dislike',
        count: count,
        onTap: onTap,
        activeColor: context.omnia.text,
      );
}

/// "Show replies", with the stacked avatars of the people in the sub-thread —
/// Threads' affordance for a collapsed run.
class ThreadMoreReplies extends StatelessWidget {
  const ThreadMoreReplies({
    super.key,
    required this.avatars,
    required this.onTap,
    this.label = 'Show replies',
    this.indent = 0,
  });

  /// Up to three faces are drawn; the rest are implied.
  final List<Widget> avatars;
  final VoidCallback onTap;
  final String label;
  final double indent;

  static const double _size = 18;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final shown = avatars.take(3).toList();

    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: label,
      child: Padding(
        padding: EdgeInsets.only(
          left: indent,
          top: Space.sm,
          bottom: Space.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              // Each face overlaps the previous by a third of its width.
              width: shown.isEmpty
                  ? 0
                  : _size + (shown.length - 1) * (_size * 0.66),
              height: _size,
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: i * (_size * 0.66),
                      child: Container(
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: o.bg, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: shown[i],
                      ),
                    ),
                ],
              ),
            ),
            if (shown.isNotEmpty) const SizedBox(width: Space.md),
            // Flexible, because this row already starts indented by the depth
            // of the sub-thread it stands in for: deep enough in, or at a
            // large text size, the label is wider than what is left.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: FontSizes.sm,
                  fontWeight: Weights.medium,
                  color: o.textLow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connectors
// ---------------------------------------------------------------------------

/// Geometry shared by the thread connectors, so the painter and the widgets
/// that lay out around it cannot drift apart.
class ThreadGeometry {
  ThreadGeometry._();

  /// How far each nesting level indents. Also the horizontal distance an
  /// elbow travels, so the curve's proportions stay the same at any depth.
  static const double indent = 30;

  /// Rail thickness. Deliberately 2px: a 1px line is indistinguishable from
  /// the hairlines that separate rows, and stops reading as a connector.
  static const double thickness = 2;

  /// Radius of the elbow's corner. Roughly half the indent, which is what
  /// makes the turn read as a quarter-circle rather than a clipped corner.
  static const double corner = 12;

  /// Deepest level that still indents. Past this, replies keep threading but
  /// stop marching rightward — otherwise a long argument runs out of screen.
  static const int maxIndent = 4;

  static double indentFor(int depth) => indent * (depth.clamp(0, maxIndent));
}

/// The quarter-circle turning out of a parent's rail into a reply's avatar.
///
/// This is the piece that says "this answers the thing above", and the reason
/// a bare vertical line is not enough: without the turn, a nested reply reads
/// as a new top-level comment that happens to be indented.
class ThreadElbow {
  const ThreadElbow({
    required this.x,
    required this.turnY,
    required this.endX,
    required this.radius,
  });

  /// The parent rail's centre line, where the elbow drops from.
  final double x;

  /// Where it turns — the avatar's vertical centre, so the curve arrives at
  /// the face rather than above or below it.
  final double turnY;

  /// Where it stops: the left edge of this row's avatar.
  final double endX;

  final double radius;

  Path toPath() => Path()
    ..moveTo(x, 0)
    ..lineTo(x, turnY - radius)
    ..arcToPoint(
      Offset(x + radius, turnY),
      radius: Radius.circular(radius),
      clockwise: false,
    )
    ..lineTo(endX, turnY);

  @override
  bool operator ==(Object other) =>
      other is ThreadElbow &&
      other.x == x &&
      other.turnY == turnY &&
      other.endX == endX &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(x, turnY, endX, radius);
}

/// Everything drawn in one row's connector strip, worked out before a single
/// line is painted.
///
/// Separating the geometry from the painting is what makes it testable: a
/// connector that runs to the wrong place still paints without complaint, so
/// the only way to catch it is to assert on the numbers.
class ThreadConnectorPlan {
  const ThreadConnectorPlan({
    required this.railXs,
    required this.elbow,
    required this.parentRailBelowX,
    required this.ownRailX,
    required this.ownRailTop,
  });

  /// Full-height verticals for ancestors whose threads continue past this row.
  final List<double> railXs;

  /// The turn out of the immediate parent, or null at top level.
  final ThreadElbow? elbow;

  /// The parent's rail carrying on below this row — set only for a middle
  /// child, since the last child is where a parent's thread ends.
  final double? parentRailBelowX;

  /// This row's own rail, drawn only when replies are rendered beneath it.
  /// Null for a childless comment: the bug where two unrelated comments were
  /// stitched together by a rail belonging to neither.
  final double? ownRailX;

  /// Where that rail starts — just under the avatar, not at its centre.
  final double ownRailTop;

  static ThreadConnectorPlan forRow({
    required int depth,
    required List<bool> ancestorRails,
    required bool hasChildrenBelow,
    required bool isLastChild,
    required double avatarSize,
  }) {
    double centreOf(int level) =>
        ThreadGeometry.indentFor(level) + avatarSize / 2;
    final turnY = avatarSize / 2;

    final rails = <double>[
      for (var level = 0; level < depth; level++)
        if (level < ancestorRails.length && ancestorRails[level])
          centreOf(level),
    ];

    ThreadElbow? elbow;
    double? parentBelow;
    if (depth > 0) {
      final parentX = centreOf(depth - 1);
      final avatarLeft = ThreadGeometry.indentFor(depth);
      // Never let the corner exceed the space available, or the arc inverts.
      final radius = ThreadGeometry.corner
          .clamp(0.0, (avatarLeft - parentX).abs())
          .clamp(0.0, turnY)
          .toDouble();
      elbow = ThreadElbow(
        x: parentX,
        turnY: turnY,
        endX: avatarLeft,
        radius: radius,
      );
      if (!isLastChild) parentBelow = parentX;
    }

    return ThreadConnectorPlan(
      railXs: List.unmodifiable(rails),
      elbow: elbow,
      parentRailBelowX: parentBelow,
      ownRailX: hasChildrenBelow ? centreOf(depth) : null,
      ownRailTop: avatarSize + Space.xs,
    );
  }
}

/// Draws the rails and elbows to the left of one thread row.
class ThreadConnectorPainter extends CustomPainter {
  const ThreadConnectorPainter({
    required this.depth,
    required this.ancestorRails,
    required this.hasChildrenBelow,
    required this.isLastChild,
    required this.avatarSize,
    required this.color,
  });

  final int depth;

  /// Per ancestor level (0 … depth-1): does that ancestor have a later sibling,
  /// meaning its rail passes this row rather than ending above it?
  final List<bool> ancestorRails;

  final bool hasChildrenBelow;

  /// Whether this row is the final child of its parent — if so the parent's
  /// rail terminates in this row's elbow instead of continuing down.
  final bool isLastChild;

  final double avatarSize;
  final Color color;

  ThreadConnectorPlan get plan => ThreadConnectorPlan.forRow(
        depth: depth,
        ancestorRails: ancestorRails,
        hasChildrenBelow: hasChildrenBelow,
        isLastChild: isLastChild,
        avatarSize: avatarSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ThreadGeometry.thickness
      ..strokeCap = StrokeCap.round;

    final p = plan;

    for (final x in p.railXs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    if (p.elbow case final elbow?) {
      canvas.drawPath(elbow.toPath(), paint);
    }

    if (p.parentRailBelowX case final x?) {
      canvas.drawLine(
        Offset(x, p.elbow?.turnY ?? 0),
        Offset(x, size.height),
        paint,
      );
    }

    if (p.ownRailX case final x?) {
      canvas.drawLine(
        Offset(x, p.ownRailTop),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ThreadConnectorPainter old) =>
      old.depth != depth ||
      old.hasChildrenBelow != hasChildrenBelow ||
      old.isLastChild != isLastChild ||
      old.avatarSize != avatarSize ||
      old.color != color ||
      !listEquals(old.ancestorRails, ancestorRails);
}

/// One row of a thread: connectors and avatar on the left, content on the
/// right.
///
/// The connector strip is painted *behind* the row rather than laid out beside
/// it, so an elbow can reach across the gutter into the avatar without any
/// widget having to know the geometry.
class ThreadItem extends StatelessWidget {
  const ThreadItem({
    super.key,
    required this.depth,
    required this.ancestorRails,
    required this.hasChildrenBelow,
    required this.isLastChild,
    required this.avatar,
    required this.child,
    this.avatarSize = 34,
  });

  final int depth;
  final List<bool> ancestorRails;
  final bool hasChildrenBelow;
  final bool isLastChild;
  final Widget avatar;
  final Widget child;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final indent = ThreadGeometry.indentFor(depth);

    return IntrinsicHeight(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ThreadConnectorPainter(
                depth: depth,
                ancestorRails: ancestorRails,
                hasChildrenBelow: hasChildrenBelow,
                isLastChild: isLastChild,
                avatarSize: avatarSize,
                color: o.borderMedium,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: avatarSize, height: avatarSize, child: avatar),
                const SizedBox(width: Space.md),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
