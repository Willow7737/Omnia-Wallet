import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/motion.dart';
import 'app_lock.dart';

/// Full-screen lock overlay shown when the app is locked. Auto-prompts for
/// biometrics on appear and offers a manual retry.
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
          _hint = 'Biometrics unavailable on this device.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1),
                  duration: Motion.slow,
                  curve: Motion.springy,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Wallet locked', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Unlock with biometrics to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_hint != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _attempt,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(_busy ? 'Unlocking…' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
