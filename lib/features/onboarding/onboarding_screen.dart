import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/method_card.dart';
import '../../state/providers.dart';

/// First-run flow, in two phases:
///  1. **Slides** — a swipeable intro (Skip top-right, dots, Next/Get started)
///     with collage-style illustrations.
///  2. **Methods** — create / import / sign in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide({required this.asset, required this.title, required this.body});
  final String asset;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    asset: 'assets/illustrations/onb_wallet.svg',
    title: 'Meet your Omnia wallet',
    body: 'Universal Basic Compute, in your pocket. Check your balance, '
        'follow your activity, and carry your identity everywhere.',
  ),
  _Slide(
    asset: 'assets/illustrations/onb_keys.svg',
    title: 'Your keys, your DID',
    body: 'Create a self-custody wallet whose keys never leave this device — '
        'or sign in with the Omnia account you already use on the web.',
  ),
  _Slide(
    asset: 'assets/illustrations/onb_send.svg',
    title: 'Send. Vote. Take part.',
    body: 'Spend UBC in a couple of taps and have your say on governance '
        'proposals that steer the protocol.',
  ),
  _Slide(
    asset: 'assets/illustrations/onb_news.svg',
    title: 'Stay in the loop',
    body: 'Transaction alerts and news from the Omnia team keep you close to '
        'where the protocol is heading.',
  ),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _showMethods = false;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toMethods() {
    Haptics.medium();
    setState(() => _showMethods = true);
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      _toMethods();
      return;
    }
    Haptics.light();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

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
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showMethods ? _buildMethods(context) : _buildSlides(context),
        ),
      ),
    );
  }

  // ---- Phase 1: slides ----

  Widget _buildSlides(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _index == _slides.length - 1;

    return Column(
      key: const ValueKey('slides'),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
            child: TextButton(
              onPressed: _toMethods,
              child: const Text('Skip'),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) {
              Haptics.selection();
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset(slide.asset, height: 250),
                    const SizedBox(height: 32),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Page dots.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: FilledButton(
            onPressed: _next,
            child: Text(isLast ? 'Get started' : 'Next'),
          ),
        ),
      ],
    );
  }

  // ---- Phase 2: choose a sign-in method ----

  Widget _buildMethods(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('methods'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero: brand mark over a soft halftone/blue glow illustration.
          FadeSlideIn(
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/illustrations/hero_dots.svg',
                    height: 260,
                  ),
                  const BrandMark(size: 96),
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
              'How would you like to start?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
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
            MethodCard(
              icon: Icons.add_circle_outline,
              title: 'Create a new wallet',
              subtitle: 'Generate a fresh recovery phrase',
              primary: true,
              onTap: _create,
            ),
            const SizedBox(height: 12),
            MethodCard(
              icon: Icons.download_outlined,
              title: 'Import from recovery phrase',
              subtitle: 'Restore an existing wallet',
              primary: false,
              onTap: _import,
            ),
            const SizedBox(height: 12),
            MethodCard(
              icon: Icons.person_outline,
              title: 'Sign in with your Omnia account',
              subtitle: 'Google, GitHub, or email — from the web app',
              primary: false,
              onTap: () {
                Haptics.light();
                context.push('/signin');
              },
            ),
          ],
        ],
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
