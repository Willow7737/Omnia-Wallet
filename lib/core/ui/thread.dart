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

/// The heart, with the pop Threads gives it on the way in.
class ThreadLikeAction extends StatefulWidget {
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
  State<ThreadLikeAction> createState() => _ThreadLikeActionState();
}

class _ThreadLikeActionState extends State<ThreadLikeAction>
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
    // Only the *liking* direction pops. Un-liking with a flourish would
    // celebrate the wrong thing.
    if (!widget.liked) {
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
        icon: widget.liked ? Iconsax.heart : Iconsax.heart_copy,
        label: 'Like',
        count: widget.count,
        color: widget.liked ? o.like : null,
        onTap: _tap,
      ),
    );
  }
}

/// The avatar column, and the hairline rail that continues below it.
///
/// [railBelow] draws the connector down to the next item in the thread; the
/// last item in a run leaves it off so the thread visibly ends.
class ThreadRail extends StatelessWidget {
  const ThreadRail({
    super.key,
    required this.avatar,
    required this.size,
    this.railBelow = true,
  });

  final Widget avatar;
  final double size;
  final bool railBelow;

  /// Rail thickness. Deliberately 2px: a 1px line disappears against the
  /// hairlines that separate rows, and stops reading as a connector.
  static const double thickness = 2;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return SizedBox(
      width: size,
      child: Column(
        children: [
          SizedBox(width: size, height: size, child: avatar),
          if (railBelow)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Container(width: thickness, color: o.borderMedium),
              ),
            ),
        ],
      ),
    );
  }
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
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                fontWeight: Weights.medium,
                color: o.textLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
