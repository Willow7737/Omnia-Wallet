import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import 'press.dart';

/// Button colour intent. Mirrors ALF's `color` prop.
enum ButtonColor { primary, secondary, negative, positiveTonal, negativeTonal }

/// Button fill style. Mirrors ALF's `variant` prop.
enum ButtonVariant { solid, outline, ghost }

/// Button geometry. Values transcribed from `src/components/Button.tsx`:
///
/// | size  | padV | padH | gap | text          |
/// |-------|------|------|-----|---------------|
/// | large | 12   | 24   | 6   | 15 / medium   |
/// | small | 8    | 14   | 5   | 13.1 / medium |
/// | tiny  | 5    | 10   | 3   | 11.3 / semi   |
enum ButtonSize { large, small, tiny }

/// The app's button.
///
/// Every size is a **full pill** — ALF uses `borderRadius.full` at all sizes,
/// which is the single most recognisable thing about a Bluesky button. There
/// is no elevation and no ripple; pressing scales and dims via [Pressable].
class OmniaButton extends StatelessWidget {
  const OmniaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.color = ButtonColor.primary,
    this.variant = ButtonVariant.solid,
    this.size = ButtonSize.large,
    this.expand = false,
    this.loading = false,
  });

  /// A full-width primary action — the shape used at the bottom of forms.
  const OmniaButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.size = ButtonSize.large,
  })  : color = ButtonColor.primary,
        variant = ButtonVariant.solid,
        expand = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final ButtonColor color;
  final ButtonVariant variant;
  final ButtonSize size;

  /// Stretch to the available width.
  final bool expand;

  /// Swap the label for a spinner and refuse taps.
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  EdgeInsets get _padding => switch (size) {
        ButtonSize.large => const EdgeInsets.symmetric(
            vertical: Space.md,
            horizontal: Space.xxl,
          ),
        ButtonSize.small => const EdgeInsets.symmetric(
            vertical: Space.sm,
            horizontal: Space.lg - 2,
          ),
        ButtonSize.tiny => const EdgeInsets.symmetric(
            vertical: 5,
            horizontal: Space.sm + 2,
          ),
      };

  double get _gap => switch (size) {
        ButtonSize.large => 6,
        ButtonSize.small => 5,
        ButtonSize.tiny => 3,
      };

  double get _fontSize => switch (size) {
        ButtonSize.large => FontSizes.md,
        ButtonSize.small => FontSizes.sm,
        ButtonSize.tiny => FontSizes.xs,
      };

  FontWeight get _weight => switch (size) {
        ButtonSize.tiny => Weights.semiBold,
        _ => Weights.medium,
      };

  double get _iconSize => switch (size) {
        ButtonSize.large => 18,
        ButtonSize.small => 16,
        ButtonSize.tiny => 13,
      };

  ({Color bg, Color fg, Color? border}) _palette(OmniaColors o) {
    final p = o.palette;

    if (!_enabled) {
      return switch (variant) {
        ButtonVariant.solid => (
            bg: color == ButtonColor.negative
                ? p.negative700
                : o.accentDisabled,
            fg: o.textInverted,
            border: null,
          ),
        _ => (bg: Colors.transparent, fg: o.textLow, border: o.borderLow),
      };
    }

    return switch (variant) {
      ButtonVariant.solid => switch (color) {
          ButtonColor.primary => (
              bg: o.accent,
              fg: OmniaPalette.white,
              border: null,
            ),
          ButtonColor.secondary => (
              bg: o.bg50,
              fg: o.textHigh,
              border: null,
            ),
          ButtonColor.negative => (
              bg: o.negativeSolid,
              fg: OmniaPalette.white,
              border: null,
            ),
          ButtonColor.positiveTonal => (
              bg: o.positive.withValues(alpha: 0.14),
              fg: o.positive,
              border: null,
            ),
          ButtonColor.negativeTonal => (
              bg: o.negative.withValues(alpha: 0.14),
              fg: o.negative,
              border: null,
            ),
        },
      ButtonVariant.outline => (
          bg: Colors.transparent,
          fg: switch (color) {
            ButtonColor.primary => o.link,
            ButtonColor.negative || ButtonColor.negativeTonal => o.negative,
            ButtonColor.positiveTonal => o.positive,
            ButtonColor.secondary => o.textHigh,
          },
          border: switch (color) {
            ButtonColor.primary => o.accent.withValues(alpha: 0.5),
            ButtonColor.negative ||
            ButtonColor.negativeTonal =>
              o.negative.withValues(alpha: 0.5),
            ButtonColor.positiveTonal => o.positive.withValues(alpha: 0.5),
            ButtonColor.secondary => o.borderMedium,
          },
        ),
      ButtonVariant.ghost => (
          bg: Colors.transparent,
          fg: switch (color) {
            ButtonColor.primary => o.link,
            ButtonColor.negative || ButtonColor.negativeTonal => o.negative,
            ButtonColor.positiveTonal => o.positive,
            ButtonColor.secondary => o.textMedium,
          },
          border: null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final c = _palette(o);

    final content = loading
        ? SizedBox(
            height: _fontSize * 1.2,
            width: _fontSize * 1.2,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.fg),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _iconSize, color: c.fg),
                SizedBox(width: _gap),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: _fontSize,
                    fontWeight: _weight,
                    letterSpacing: kTracking,
                    height: 1.2,
                    color: c.fg,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                SizedBox(width: _gap),
                Icon(trailingIcon, size: _iconSize, color: c.fg),
              ],
            ],
          );

    return Pressable(
      onTap: _enabled ? onPressed : null,
      feel: PressFeel.firm,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.micro,
        width: expand ? double.infinity : null,
        padding: _padding,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: Radii.rFull,
          border: c.border == null ? null : Border.all(color: c.border!),
        ),
        child: content,
      ),
    );
  }
}

/// A round, borderless icon target — the header/toolbar affordance.
///
/// 40pt is the smallest square that still clears the 44pt touch minimum once
/// the surrounding row padding is counted; below that, add [padding].
class OmniaIconButton extends StatelessWidget {
  const OmniaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 20,
    this.box = 40,
    this.color,
    this.background,
    this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double box;
  final Color? color;
  final Color? background;
  final String? tooltip;

  /// Draw an unread dot on the top-right corner.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    Widget child = Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size, color: color ?? o.text),
          if (badge)
            Positioned(
              right: box * 0.22,
              top: box * 0.22,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: o.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: o.bg, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: tooltip,
      child: child,
    );
  }
}

/// Text that behaves like a link: accent-coloured, dims on press, no chrome.
class OmniaTextButton extends StatelessWidget {
  const OmniaTextButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
    this.size = FontSizes.md,
    this.weight = Weights.semiBold,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.omnia.link;
    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Space.sm,
          horizontal: Space.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: size, color: tint),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: size,
                fontWeight: weight,
                letterSpacing: kTracking,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
