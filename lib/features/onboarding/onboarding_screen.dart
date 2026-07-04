import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../state/providers.dart';

/// First-run: create a new wallet (showing the recovery phrase) or import one.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  Future<void> _create() async {
    Haptics.medium();
    setState(() => _busy = true);
    try {
      final mnemonic = await ref.read(authRepositoryProvider).createWallet();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RecoveryDialog(mnemonic: mnemonic),
      );
      _finish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    Haptics.light();
    final phrase = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (phrase == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).importWallet(phrase);
      _finish();
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    ref.invalidate(hasWalletProvider);
    ref.invalidate(identityProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              FadeSlideIn(
                child: Text('omnia', style: theme.textTheme.displaySmall),
              ),
              const SizedBox(height: 8),
              Text(
                'A self-custodial wallet for Universal Basic Compute.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton(
                  onPressed: _create,
                  child: const Text('Create a new wallet'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _import,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Import from recovery phrase'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Your keys are generated on this device and never leave it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({required this.mnemonic});
  final String mnemonic;

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.mnemonic.split(' ');
    return AlertDialog(
      title: const Text('Your recovery phrase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Write these 12 words down in order and keep them offline. '
              'Anyone with this phrase controls your wallet. It is the only '
              'way to recover it.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < words.length; i++)
                  Chip(label: Text('${i + 1}. ${words[i]}')),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: widget.mnemonic)),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              title: const Text('I have saved my recovery phrase'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop() : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import wallet'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter your 12-word recovery phrase',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
