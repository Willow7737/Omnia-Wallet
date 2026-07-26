import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../motion.dart';
import '../theme.dart';

/// One destination in [OmniaTabBar].
///
/// Iconsax ships every glyph twice: the bare name is the **bold** cut and the
/// `_copy` suffix is the **linear** cut (verified by rendering the glyphs out
/// of `FlutterIconsax.ttf`). That pairing is exactly what a Bluesky-style tab
/// bar needs — linear when inactive, bold when active — so a tab is declared
/// as `icon: Iconsax.home_copy, activeIcon: Iconsax.home`.
class OmniaTab {
  const OmniaTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.showDot = false,
  });

  /// Linear cut, shown when the tab is not selected.
  final IconData icon;

  /// Bold cut, shown when the tab is selected.
  final IconData activeIcon;

  /// Read by screen readers, and drawn only under the active tab.
  final String label;

  final int? badgeCount;
  final bool showDot;
}

/// The bottom tab bar.
///
/// Bluesky's bar is translucent, closed by a 1px top hairline, and shows **no
/// labels** — the icon weight alone carries selection. It is always visible;
/// pushed screens go over the whole shell rather than under it.
class OmniaTabBar extends StatelessWidget {
  const OmniaTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<OmniaTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  static const double barHeight = 50;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: o.bg.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: o.borderLow)),
          ),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      tab: tabs[i],
                      selected: i == index,
                      onTap: () {
                        // Re-tapping the active tab is a scroll-to-top gesture
                        // elsewhere; either way the tick belongs on touch.
                        Haptics.tick();
                        onSelect(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final OmniaTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.fast,
    lowerBound: 0.86,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// A quick dip-and-spring on the icon when the tab is chosen. Short enough
  /// that it reads as the icon *reacting*, not as an animation playing.
  void _bounce() {
    _c.animateTo(0.86, duration: Motion.micro, curve: Motion.exit).then((_) {
      if (mounted) {
        _c.animateTo(1.0, duration: Motion.fast, curve: Motion.springy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final tab = widget.tab;
    final tint = widget.selected ? o.text : o.textLow;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _bounce(),
        onTap: widget.onTap,
        child: Center(
          child: ScaleTransition(
            scale: _c,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Cross-fading the two weights (rather than swapping them)
                // keeps the stroke from popping when a tab is selected.
                AnimatedSwitcher(
                  duration: Motion.fast,
                  switchInCurve: Motion.standard,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Icon(
                    widget.selected ? tab.activeIcon : tab.icon,
                    key: ValueKey(widget.selected),
                    size: 25,
                    color: tint,
                  ),
                ),
                if ((tab.badgeCount ?? 0) > 0)
                  Positioned(
                    top: -6,
                    left: 12,
                    child: _Badge(count: tab.badgeCount!),
                  )
                else if (tab.showDot)
                  Positioned(
                    top: -2,
                    left: 14,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: o.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: o.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: o.accent,
        borderRadius: Radii.rFull,
        border: Border.all(color: o.bg, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: OmniaPalette.white,
          fontSize: FontSizes.xxs + 1,
          fontWeight: Weights.bold,
          height: 1.3,
        ),
      ),
    );
  }
}
