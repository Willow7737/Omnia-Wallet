import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import 'app_lock.dart';

/// The full-screen lock overlay.
///
/// Auto-prompts for biometrics on appear and offers a manual retry. Nothing
/// behind it is ever visible — this is a wallet, and a locked wallet must not
/// leak a balance through a blur.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _hint = null;
    });

    final result = await ref.read(appLockProvider.notifier).unlock();
    if (!mounted) return;

    setState(() {
      _busy = false;
      switch (result) {
        case UnlockResult.success:
          Haptics.success();
          _hint = null;
        case UnlockResult.failed:
          Haptics.error();
          _hint = 'Authentication failed. Try again.';
        case UnlockResult.unavailable:
          _hint = 'Biometrics are unavailable on this device.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: o.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x4l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.88, end: 1),
                  duration: Motion.slow,
                  curve: Motion.springy,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.lock_1, size: 34, color: o.accent),
                  ),
                ),
                const SizedBox(height: Space.xxl),
                Text('Wallet locked', style: theme.textTheme.headlineMedium),
                const SizedBox(height: Space.sm),
                Text(
                  'Unlock with biometrics to continue.',
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
                ),
                if (_hint != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: o.negative),
                  ),
                ],
                const SizedBox(height: Space.x4l),
                OmniaButton(
                  label: _busy ? 'Unlocking…' : 'Unlock',
                  icon: Iconsax.finger_scan_copy,
                  loading: _busy,
                  onPressed: _busy ? null : _attempt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
