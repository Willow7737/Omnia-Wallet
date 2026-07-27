/// Empty, error and loading states.
///
/// Bluesky's empty states are quiet: a single large linear glyph at low
/// contrast, a short title, one line of explanation, and at most one action.
/// No illustrations, no card, no border.
library;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../haptics.dart';
import '../motion.dart';
import '../theme.dart';
import 'button.dart';

class OmniaEmptyState extends StatelessWidget {
  const OmniaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.bottomInset = 0,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter padding, for an empty state that sits inside a section rather
  /// than filling a screen.
  final bool compact;

  /// Space at the bottom that is covered by something floating over the body
  /// — the tab bar. Without it, "centred" is centred behind that bar and the
  /// block sits visibly low.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Space.x4l,
        vertical: compact ? Space.x4l : Space.x5l + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 36 : 44, color: o.borderHigh),
          SizedBox(height: compact ? Space.md : Space.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(color: o.textHigh),
          ),
          if (message != null) ...[
            const SizedBox(height: Space.xs + 2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: o.textLow),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.xl),
            OmniaButton(
              label: actionLabel!,
              size: ButtonSize.small,
              color: ButtonColor.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );

    // Two very different homes for the same widget: inside a scroll view,
    // where height is unbounded and it must simply take the room it needs;
    // and filling a screen's body, where a fixed top padding leaves it
    // stranded in the upper third with a large void underneath. Centring is
    // only possible — and only correct — in the second case.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return content;
        return Center(
          // Scrollable so a long message at a large text size can still be
          // read rather than overflowing a fixed height.
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: content,
          ),
        );
      },
    );
  }
}

/// A failure, with a retry. Never a bare exception string.
class OmniaErrorState extends StatelessWidget {
  const OmniaErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OmniaEmptyState(
      icon: icon ?? Iconsax.warning_2_copy,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// A shimmering placeholder block.
///
/// The gradient sweep is a single repeating controller shared by the whole
/// block, and it runs at low contrast (a 6% delta) — a bright shimmer reads as
/// a bug rather than as loading.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = Radii.sm,
  });

  /// A pill-shaped line of text.
  const Skeleton.line({
    super.key,
    required this.width,
    this.height = 12,
  }) : radius = Radii.full;

  /// A circular avatar placeholder.
  const Skeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = Radii.full;

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final base = o.bg50;
    final highlight = Color.lerp(base, o.text, 0.06)!;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Travel from fully off the left to fully off the right so the sweep
        // never appears to start mid-block.
        final dx = (_c.value * 3) - 1.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx - 0.7, 0),
              end: Alignment(dx + 0.7, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Fades and lifts its child on first build, with an optional [delay] so a
/// list produces a stagger. Purely decorative — the child is interactive the
/// whole time.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 8,
  });

  final Widget child;
  final Duration delay;

  /// Vertical travel, in logical pixels. Kept small: a list where every row
  /// flies in from far away reads as a loading screen, not as content.
  final double offset;

  /// Stagger helper — caps the delay so row 40 doesn't wait two seconds.
  static Duration stagger(int index, {int step = 35, int cap = 6}) =>
      Duration(milliseconds: step * (index.clamp(0, cap)));

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Pull-to-refresh with the app's accent and a haptic when it fires.
///
/// Material's own indicator arms silently; the haptic on trigger is what makes
/// a pull feel like it *caught*.
class OmniaRefresh extends StatelessWidget {
  const OmniaRefresh({super.key, required this.child, required this.onRefresh});

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return RefreshIndicator(
      onRefresh: () {
        Haptics.refresh();
        return onRefresh();
      },
      color: o.accent,
      backgroundColor: o.bg,
      strokeWidth: 2.5,
      displacement: 24,
      child: child,
    );
  }
}

/// A blocking progress overlay for an action that must finish before the user
/// moves on (signing and broadcasting a transfer).
///
/// Dismissed even when [task] throws.
Future<T> runWithOverlay<T>(
  BuildContext context,
  Future<T> Function() task, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final o = context.omnia;
  var visible = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: o.scrim,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xxl,
            vertical: Space.xl,
          ),
          decoration: BoxDecoration(
            color: o.bg,
            borderRadius: Radii.rLg,
            border: Border.all(color: o.borderLow),
            boxShadow: o.shadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: o.accent,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Space.lg),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.sm,
                    fontWeight: Weights.medium,
                    color: o.textMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => visible = false);

  try {
    return await task();
  } finally {
    if (visible && navigator.mounted) navigator.pop();
  }
}
