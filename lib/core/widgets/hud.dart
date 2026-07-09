import 'package:flutter/material.dart';

/// A blocking loading HUD: the screen dims and a small rounded square with a
/// spinner sits dead center (iOS-style progress HUD).
///
/// Wrap any async action:
/// ```dart
/// final result = await runWithHud(context, () => repo.send(...));
/// ```
/// The HUD is dismissed even when the task throws.
Future<T> runWithHud<T>(BuildContext context, Future<T> Function() task) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var hudVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    useRootNavigator: true,
    builder: (_) => const PopScope(canPop: false, child: _HudBox()),
  ).whenComplete(() => hudVisible = false);

  try {
    return await task();
  } finally {
    if (hudVisible && navigator.mounted) {
      navigator.pop();
    }
  }
}

class _HudBox extends StatelessWidget {
  const _HudBox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
