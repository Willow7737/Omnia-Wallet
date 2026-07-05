import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/press_scale.dart';
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
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: brand mark over a soft halftone/blue glow illustration.
              FadeSlideIn(
                child: SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/illustrations/hero_dots.svg',
                        height: 300,
                      ),
                      const BrandMark(size: 104),
                    ],
                  ),
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Center(
                  child: Text('omnia', style: theme.textTheme.displaySmall),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'A self-custodial wallet for Universal Basic Compute.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
              const _Feature(
                icon: Icons.key_outlined,
                text:
                    'Your keys are generated on this device and never leave it.',
              ),
              const _Feature(
                icon: Icons.bolt_outlined,
                text: 'Send UBC and check your balance in a tap.',
              ),
              const _Feature(
                icon: Icons.how_to_vote_outlined,
                text: 'Vote on governance proposals.',
              ),
              const SizedBox(height: 28),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _MethodCard(
                  icon: Icons.add_circle_outline,
                  title: 'Create a new wallet',
                  subtitle: 'Generate a fresh recovery phrase',
                  primary: true,
                  onTap: _create,
                ),
                const SizedBox(height: 12),
                _MethodCard(
                  icon: Icons.download_outlined,
                  title: 'Import from recovery phrase',
                  subtitle: 'Restore an existing wallet',
                  primary: false,
                  onTap: _import,
                ),
              ],
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

/// A small icon + text row used for the onboarding value props.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A tappable "sign-in method" card for the onboarding actions.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = primary ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = primary ? scheme.onPrimary : scheme.onSurface;
    final sub = primary
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: primary ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: sub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: sub),
          ],
        ),
      ),
    );
  }
}
