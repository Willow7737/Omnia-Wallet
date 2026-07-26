import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../theme.dart';
import 'button.dart';

/// The app's screen header.
///
/// Bluesky's header is short (about 52pt), left-aligned, translucent, and
/// closed by a **1px hairline** rather than a shadow or a tonal elevation
/// overlay. It stays put while content scrolls under it, blurred.
///
/// This is deliberately *not* a Material `AppBar`: `AppBar` insists on a
/// `scrolledUnderElevation` tint, a 56pt minimum, and centred titles on iOS.
class OmniaHeader extends StatelessWidget implements PreferredSizeWidget {
  const OmniaHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.transparent = false,
    this.centerTitle = false,
  });

  final String? title;

  /// Wins over [title] — for a wordmark or a two-line title block.
  final Widget? titleWidget;

  /// Wins over the automatic back button.
  final Widget? leading;

  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  /// Pinned under the title row and inside the blur — segmented controls,
  /// filter chips.
  final PreferredSizeWidget? bottom;

  /// Drop the background fill and the hairline (for content that bleeds to
  /// the top edge, like the scanner).
  final bool transparent;

  final bool centerTitle;

  static const double _barHeight = 52;

  /// Everything this widget draws *below* the status bar.
  ///
  /// The status-bar inset is deliberately excluded: `Scaffold` adds
  /// `MediaQuery.padding.top` on top of `preferredSize` for the app-bar slot,
  /// and [build] consumes that inset itself. The closing hairline has to be
  /// counted here — leaving it out is a 1px overflow on every screen in the
  /// app, which is exactly what it was.
  @override
  Size get preferredSize => Size.fromHeight(
        _barHeight +
            (bottom?.preferredSize.height ?? 0) +
            (transparent ? 0 : _hairline),
      );

  static const double _hairline = 1;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    final Widget? lead = leading ??
        (showBack && canPop
            ? OmniaIconButton(
                icon: Iconsax.arrow_left_2_copy,
                size: 22,
                tooltip: 'Back',
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null);

    final titleContent = titleWidget ??
        (title == null
            ? const SizedBox.shrink()
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ));

    final bar = SizedBox(
      height: _barHeight,
      child: Row(
        children: [
          SizedBox(
            width: lead == null ? Space.lg : Space.sm,
            child: const SizedBox.shrink(),
          ),
          if (lead != null) lead,
          if (lead != null) const SizedBox(width: Space.xs),
          Expanded(
            child: Align(
              alignment:
                  centerTitle ? Alignment.center : Alignment.centerLeft,
              child: titleContent,
            ),
          ),
          ...actions,
          const SizedBox(width: Space.sm),
        ],
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: MediaQuery.viewPaddingOf(context).top),
        bar,
        if (bottom != null) bottom!,
        if (!transparent) Container(height: _hairline, color: o.borderLow),
      ],
    );

    if (transparent) return column;

    // Opaque when blur is off, so content scrolling underneath never shows
    // through a bar that is no longer frosting it.
    if (!kBlurEnabled) return ColoredBox(color: o.bg, child: column);

    // Blur what scrolls beneath, then wash it with the page colour so text
    // stays legible over busy content.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(
          color: o.bg.withValues(alpha: 0.88),
          child: column,
        ),
      ),
    );
  }
}

/// A header that participates in a `CustomScrollView` — pinned, blurred, with
/// the same hairline. Use when the screen is a sliver list.
class OmniaSliverHeader extends StatelessWidget {
  const OmniaSliverHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.showBack = true,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final header = OmniaHeader(
      title: title,
      titleWidget: titleWidget,
      leading: leading,
      actions: actions,
      showBack: showBack,
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        header: header,
        height: header.preferredSize.height +
            MediaQuery.viewPaddingOf(context).top,
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.header, required this.height});

  final Widget header;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      header;

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.height != height || old.header != header;
}
