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
    this.verified = false,
  });

  final String name;
  final String timestamp;
  final VoidCallback? onMore;
  final String moreTooltip;
  final TextStyle? nameStyle;

  /// Shows the verified tick beside the name.
  final bool verified;

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
              if (verified) ...[
                const SizedBox(width: Space.xs),
                const VerifiedBadge(),
              ],
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

/// The verified tick.
///
/// Filled rather than outlined, and in the accent blue, because at this size
/// an outline is mush — the shape has to be readable at 15px beside a name.
/// Carries a semantics label so it is not silence to a screen reader.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 15});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified',
      child: Icon(
        Iconsax.verify,
        size: size,
        color: context.omnia.accent,
      ),
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

/// "Show replies": the stacked faces of who is in the held-back sub-thread,
/// a chevron badge, and the invitation.
///
/// Built as a [ThreadItem] rather than a plain indented row, which is what
/// makes it behave like part of the thread instead of a label floating beside
/// it. Two things follow from that and both were wrong before:
///
///  * the faces land in the same column as the avatars of the replies they
///    stand in for, and the parent's elbow curves into them; and
///  * any ancestor rail that passes this row is painted, so a parent with
///    another answer still to come keeps its line running down the left
///    instead of breaking across the marker.
class ThreadMoreReplies extends StatelessWidget {
  const ThreadMoreReplies({
    super.key,
    required this.avatars,
    required this.onTap,
    required this.depth,
    required this.ancestorRails,
    this.label = 'Show replies',
  });

  /// Up to three faces are drawn; the rest are implied.
  final List<Widget> avatars;
  final VoidCallback onTap;

  /// Depth of the replies this stands in for — the same depth they would be
  /// drawn at, so it sits exactly where they will appear.
  final int depth;

  final List<bool> ancestorRails;
  final String label;

  static const double _size = 18;

  /// Each face overlaps the previous by a third of its width, and the chevron
  /// badge caps the stack.
  static double stackWidth(int faces) => _size + faces * (_size * 0.66);

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final shown = avatars.take(3).toList();

    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: label,
      // Padded exactly like a reply row: the gap above sits outside the
      // painted area, the gap below sits inside it. Padding both sides on the
      // outside left a double-width break in any rail passing this row.
      child: Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: ThreadItem(
          depth: depth,
          ancestorRails: ancestorRails,
          // Nothing is threaded below a marker, and it is the end of its own
          // run — it *is* the rest of the run.
          hasChildrenBelow: false,
          isLastChild: true,
          avatarSize: _size,
          avatarWidth: stackWidth(shown.length),
          avatar: Stack(
            clipBehavior: Clip.none,
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
              Positioned(
                left: shown.length * (_size * 0.66),
                child: Container(
                  width: _size,
                  height: _size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.text,
                    shape: BoxShape.circle,
                    border: Border.all(color: o.bg, width: 1.5),
                  ),
                  child: Icon(
                    Iconsax.arrow_down_1_copy,
                    size: 10,
                    color: o.bg,
                  ),
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
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

    final ownLeft = ThreadGeometry.indentFor(depth);

    // `ancestorRails[level]` says "the ancestor at `level` has a later
    // sibling". That sibling is drawn one step further left than the ancestor
    // is, because its own elbow starts from *its* parent's column — so the
    // rail that runs down to meet it belongs at `centreOf(level - 1)`, not
    // `centreOf(level)`.
    //
    // Drawing it a column too far right was visible as a line hanging under a
    // reply's avatar and running down to the reply's *aunt*, as though the two
    // were related. Index 0 is never drawn: a later sibling of a top-level
    // comment has no elbow at all, because top-level comments are separate
    // conversations.
    //
    // The result is also de-duplicated and kept left of this row's avatar:
    // past ThreadGeometry.maxIndent several levels resolve to one column, and
    // the deepest would otherwise be painted over the avatar, repeatedly.
    final rails = <double>{
      for (var level = 1; level < depth; level++)
        if (level < ancestorRails.length && ancestorRails[level])
          if (centreOf(level - 1) < ownLeft) centreOf(level - 1),
    }.toList();

    ThreadElbow? elbow;
    double? parentBelow;
    if (depth > 0) {
      final parentX = centreOf(depth - 1);
      // Past the indent cap the parent sits in the same column as the child,
      // so there is no horizontal gap for an elbow to cross. Drawing one
      // anyway hooks out to the right and then back left through the avatar.
      // The parent's own rail already runs down into this row, and a straight
      // thread is what a depth cap is supposed to look like.
      if (ownLeft > parentX) {
        // Never let the corner exceed the space available, or the arc inverts.
        final radius = ThreadGeometry.corner
            .clamp(0.0, ownLeft - parentX)
            .clamp(0.0, turnY)
            .toDouble();
        elbow = ThreadElbow(
          x: parentX,
          turnY: turnY,
          endX: ownLeft,
          radius: radius,
        );
        if (!isLastChild) parentBelow = parentX;
      }
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
    this.avatarWidth,
  });

  final int depth;
  final List<bool> ancestorRails;
  final bool hasChildrenBelow;
  final bool isLastChild;
  final Widget avatar;
  final Widget child;

  /// Height of the leading slot, and what the elbow turns into: the connector
  /// arrives at its vertical centre.
  final double avatarSize;

  /// Width of that slot when it is not square — a row of overlapping faces is
  /// wider than one avatar but should still be met by the elbow at the same
  /// place. Defaults to [avatarSize].
  final double? avatarWidth;

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
                SizedBox(
                  width: avatarWidth ?? avatarSize,
                  height: avatarSize,
                  child: avatar,
                ),
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
