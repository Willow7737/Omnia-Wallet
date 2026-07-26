import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../theme.dart';
import 'press.dart';

/// A settings/detail row.
///
/// Bluesky's lists are **full-bleed with hairline separators** — no inset
/// cards, no rounded group containers, no leading icon wells. The row itself
/// carries the horizontal padding so the separator can run edge to edge.
class OmniaRow extends StatelessWidget {
  const OmniaRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.trailingIcon,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  /// Wins over [icon].
  final Widget? leading;

  /// Wins over [trailingIcon] and [chevron].
  final Widget? trailing;

  final IconData? trailingIcon;
  final VoidCallback? onTap;

  /// Draw a disclosure chevron — only for rows that push a new screen.
  final bool chevron;

  final bool destructive;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final tint = destructive ? o.negative : o.text;

    Widget? tail = trailing;
    tail ??= trailingIcon != null
        ? Icon(trailingIcon, size: 18, color: o.textLow)
        : (chevron
            ? Icon(Iconsax.arrow_right_3_copy, size: 16, color: o.textLow)
            : null);

    return Pressable(
      onTap: onTap,
      haptic: onTap != null,
      feel: onTap == null ? PressFeel.none : PressFeel.normal,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: dense ? Space.md : Space.lg - 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Space.md + 2),
            ] else if (icon != null) ...[
              Icon(icon, size: 21, color: iconColor ?? (destructive ? tint : o.textMedium)),
              const SizedBox(width: Space.md + 2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: FontSizes.md,
                      fontWeight: Weights.medium,
                      height: LineHeights.snug,
                      color: tint,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: o.textLow,
                        height: LineHeights.snug,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (tail != null) ...[
              const SizedBox(width: Space.md),
              tail,
            ],
          ],
        ),
      ),
    );
  }
}

/// A switch row. The whole row is the target, not just the switch.
class OmniaSwitchRow extends StatelessWidget {
  const OmniaSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return OmniaRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: () => onChanged(!value),
      trailing: IgnorePointer(
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// The uppercase label that opens a group of rows.
class OmniaSectionLabel extends StatelessWidget {
  const OmniaSectionLabel(this.label, {super.key, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xxl,
        Space.sm,
        Space.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.xs,
                fontWeight: Weights.bold,
                letterSpacing: 0.6,
                color: o.textLow,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// A section heading inside a scrolling page — larger than
/// [OmniaSectionLabel], with an optional trailing action.
class OmniaSectionHeader extends StatelessWidget {
  const OmniaSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      Space.lg,
      Space.xxl,
      Space.sm,
      Space.sm,
    ),
  });

  final String title;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// The app's hairline. One pixel, `border_contrast_low`, full-bleed.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(height: 1, color: context.omnia.borderLow),
    );
  }
}

/// A pill-shaped tag. Used for statuses, provenance and finality markers.
class OmniaPill extends StatelessWidget {
  const OmniaPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  /// Solid rather than tonal — for the one pill that must dominate.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final tint = color ?? o.textMedium;
    final fg = filled ? OmniaPalette.white : tint;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm + 2,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: filled ? tint : tint.withValues(alpha: 0.12),
        borderRadius: Radii.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: Space.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: FontSizes.xs,
              fontWeight: Weights.semiBold,
              height: 1.35,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
