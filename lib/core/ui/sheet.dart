/// Bottom sheets.
///
/// Bluesky has essentially no centred alert dialogs on mobile — every
/// confirmation, picker, form and menu is a bottom sheet with a grab handle.
/// Its native sheet uses a **20pt top corner radius**
/// (`cornerRadius={20}` in `src/components/Dialog/index.tsx`), which is what
/// [Radii.sheet] carries.
///
/// Everything here shares one chrome: a 36×4 grab handle, an optional title
/// row closed by a hairline, safe-area-aware bottom padding, a haptic on open
/// and a lighter one on close.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../haptics.dart';
import '../motion.dart';
import '../theme.dart';
import 'button.dart';
import 'press.dart';

/// Present [builder] as a sheet and return whatever it pops with.
///
/// [scrollable] wraps the body in a draggable scrollable sheet, for content
/// that can outgrow the screen (long lists, forms with a keyboard). Short,
/// fixed-height content should leave it off so the sheet hugs its content.
Future<T?> showOmniaSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  String? title,
  String? subtitle,
  bool scrollable = false,
  bool dismissible = true,
  double initialSize = 0.5,
  double maxSize = 0.92,
}) async {
  Haptics.sheetOpen();
  final o = context.omnia;

  final result = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: o.scrim,
    builder: (sheetContext) {
      final body = _SheetChrome(
        title: title,
        subtitle: subtitle,
        dismissible: dismissible,
        child: builder(sheetContext),
      );

      // No SafeArea here: `useSafeArea` already keeps the sheet clear of the
      // status bar, and the home-indicator gap is added by
      // [sheetBodyPadding] on the body itself. Wrapping again would pad the
      // bottom twice.
      if (!scrollable) return body;

      const minSize = 0.25;
      return DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        snap: true,
        // A snap point has to sit strictly inside the range; passing one equal
        // to min or max trips an assertion, so an initial size at either
        // extreme means no intermediate stop.
        snapSizes: (initialSize > minSize && initialSize < maxSize)
            ? [initialSize]
            : const <double>[],
        builder: (_, controller) => _SheetChrome(
          title: title,
          subtitle: subtitle,
          dismissible: dismissible,
          scrollController: controller,
          child: builder(sheetContext),
        ),
      );
    },
  );

  Haptics.sheetClose();
  return result;
}

/// The shared sheet shell: rounded top, grab handle, optional header.
class _SheetChrome extends StatelessWidget {
  const _SheetChrome({
    required this.child,
    this.title,
    this.subtitle,
    this.dismissible = true,
    this.scrollController,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool dismissible;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final hasHeader = title != null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grab handle. Always present, even when drag is disabled — it is the
        // signal that says "this is a sheet, it came from down there".
        Padding(
          padding: const EdgeInsets.only(top: Space.sm + 2, bottom: Space.sm),
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: o.borderHigh,
                borderRadius: Radii.rFull,
              ),
            ),
          ),
        ),
        if (hasHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.xs,
              Space.sm,
              Space.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: theme.textTheme.headlineSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: Space.xs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: o.textMedium),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dismissible)
                  OmniaIconButton(
                    icon: Iconsax.close_circle_copy,
                    size: 22,
                    color: o.textLow,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: o.borderLow),
        ],
        // The handle and header stay pinned; only the body scrolls. Handing
        // the sheet's controller down as the primary one is what lets a
        // `ListView(primary: true)` inside the body drive the sheet's own
        // drag-to-resize instead of fighting it.
        if (scrollController == null)
          Flexible(child: child)
        else
          Expanded(
            child: PrimaryScrollController(
              controller: scrollController!,
              child: child,
            ),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: o.bg,
        borderRadius: Radii.sheetTop,
        border: Border(top: BorderSide(color: o.borderLow)),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Standard padding for sheet body content, including the home-indicator gap.
EdgeInsets sheetBodyPadding(BuildContext context) => EdgeInsets.fromLTRB(
      Space.xl,
      Space.lg,
      Space.xl,
      Space.xl + MediaQuery.viewPaddingOf(context).bottom,
    );

// ---------------------------------------------------------------------------
// Confirm
// ---------------------------------------------------------------------------

/// A destructive-or-not confirmation sheet. Replaces `AlertDialog` everywhere.
///
/// Returns `true` only if the user actually took the action.
Future<bool> showOmniaConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  List<({String label, String value})> details = const [],
}) async {
  final result = await showOmniaSheet<bool>(
    context,
    builder: (sheetContext) => _ConfirmBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
      details: details,
    ),
  );
  return result ?? false;
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.details,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;
  final List<({String label, String value})> details;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final tint = destructive ? o.negative : o.accent;

    return Padding(
      padding: sheetBodyPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: tint),
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Space.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            Container(
              decoration: BoxDecoration(
                color: o.bg25,
                borderRadius: Radii.rMd,
                border: Border.all(color: o.borderLow),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < details.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: o.borderLow),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                        vertical: Space.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details[i].label,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: o.textMedium),
                          ),
                          const SizedBox(width: Space.lg),
                          Expanded(
                            child: Text(
                              details[i].value,
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: Weights.semiBold,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xxl),
          OmniaButton(
            label: confirmLabel,
            expand: true,
            color: destructive ? ButtonColor.negative : ButtonColor.primary,
            onPressed: () {
              if (destructive) {
                Haptics.warning();
              } else {
                Haptics.medium();
              }
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: Space.sm),
          OmniaButton(
            label: cancelLabel,
            expand: true,
            color: ButtonColor.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

/// One row in a [showOmniaMenu].
class SheetAction<T> {
  const SheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final T value;
  final IconData? icon;
  final bool destructive;
}

/// An action sheet — the replacement for `PopupMenuButton`, which on mobile
/// pops a floating card anchored to a corner and reads as a desktop pattern.
Future<T?> showOmniaMenu<T>(
  BuildContext context, {
  required List<SheetAction<T>> actions,
  String? title,
}) {
  return showOmniaSheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        top: title == null ? 0 : Space.sm,
        bottom: Space.md + MediaQuery.viewPaddingOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            _MenuRow<T>(
              action: action,
              onTap: () => Navigator.of(sheetContext).pop(action.value),
            ),
        ],
      ),
    ),
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.action, required this.onTap});

  final SheetAction<T> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final tint = action.destructive ? o.negative : o.text;

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xl,
          vertical: Space.lg - 2,
        ),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 21, color: tint),
              const SizedBox(width: Space.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tint,
                      fontWeight: Weights.medium,
                    ),
                  ),
                  if (action.subtitle != null)
                    Text(
                      action.subtitle!,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: o.textLow),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-field input
// ---------------------------------------------------------------------------

/// A one-field form in a sheet — display name, node URL, contact label.
///
/// Resizes above the keyboard rather than being covered by it, which is the
/// main reason `AlertDialog` feels wrong for text entry on a phone.
Future<String?> showOmniaInput(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? initialValue,
  String? hintText,
  String? helperText,
  String confirmLabel = 'Save',
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int maxLines = 1,
  bool obscure = false,
  String? Function(String value)? validator,
  List<TextInputFormatter>? formatters,
}) {
  return showOmniaSheet<String>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (sheetContext) => _InputBody(
      initialValue: initialValue,
      hintText: hintText,
      helperText: helperText,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      obscure: obscure,
      validator: validator,
      formatters: formatters,
    ),
  );
}

class _InputBody extends StatefulWidget {
  const _InputBody({
    this.initialValue,
    this.hintText,
    this.helperText,
    required this.confirmLabel,
    this.keyboardType,
    required this.textCapitalization,
    required this.maxLines,
    required this.obscure,
    this.validator,
    this.formatters,
  });

  final String? initialValue;
  final String? hintText;
  final String? helperText;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final bool obscure;
  final String? Function(String value)? validator;
  final List<TextInputFormatter>? formatters;

  @override
  State<_InputBody> createState() => _InputBodyState();
}

class _InputBodyState extends State<_InputBody> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  late bool _obscured = widget.obscure;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      Haptics.error();
      setState(() => _error = error);
      return;
    }
    Haptics.selection();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        left: Space.xl,
        right: Space.xl,
        top: Space.xl,
        bottom: Space.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.formatters,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: FontSizes.lg, color: o.text),
            decoration: InputDecoration(
              hintText: widget.hintText,
              helperText: widget.helperText,
              errorText: _error,
              suffixIcon: widget.obscure
                  ? Padding(
                      padding: const EdgeInsets.only(right: Space.xs),
                      child: OmniaIconButton(
                        icon: _obscured
                            ? Iconsax.eye_slash_copy
                            : Iconsax.eye_copy,
                        size: 18,
                        color: o.textLow,
                        onTap: () => setState(() => _obscured = !_obscured),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: Space.xl),
          OmniaButton(
            label: widget.confirmLabel,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------

/// A brief confirmation, replacing `SnackBar`.
///
/// Bluesky's toast is a compact pill that floats at the *top* of the screen,
/// out of the way of the thumb and the tab bar. Material's snackbar docks to
/// the bottom, which on this app would land directly on top of the tab bar.
void showOmniaToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  bool error = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final o = context.omnia;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _Toast(
      message: message,
      icon: icon ?? (error ? Iconsax.info_circle_copy : Iconsax.tick_circle),
      tint: error ? o.negative : o.positive,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.tint,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final Color tint;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
    reverseDuration: Motion.fast,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.delayed(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final curved = CurvedAnimation(
      parent: _c,
      curve: Motion.springy,
      reverseCurve: Motion.exit,
    );

    return Positioned(
      top: MediaQuery.viewPaddingOf(context).top + Space.sm,
      left: Space.lg,
      right: Space.lg,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.6),
              end: Offset.zero,
            ).animate(curved),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.md - 2,
                ),
                decoration: BoxDecoration(
                  color: o.bg,
                  borderRadius: Radii.rFull,
                  border: Border.all(color: o.borderLow),
                  boxShadow: o.shadowMd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 18, color: widget.tint),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: FontSizes.sm,
                          fontWeight: Weights.medium,
                          color: o.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
