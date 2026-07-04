import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import 'app_lock.dart';
import 'lock_screen.dart';

/// Wraps the whole app. Loads the lock preference on start, locks whenever the
/// app is sent to the background, and overlays [LockScreen] while locked so the
/// underlying navigation state is preserved.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appLockProvider.notifier).load();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock the moment the app leaves the foreground so the app-switcher
    // snapshot and any resumed session are protected.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockProvider.notifier).lockIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider.select((s) => s.locked));

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Until the preference is read, cover content to avoid a flash of the
        // wallet before we know whether it should be locked.
        if (!_loaded) ColoredBox(color: Theme.of(context).colorScheme.surface),
        IgnorePointer(
          ignoring: !locked,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: locked
                ? const LockScreen(key: ValueKey('locked'))
                : const SizedBox.shrink(key: ValueKey('unlocked')),
          ),
        ),
      ],
    );
  }
}
