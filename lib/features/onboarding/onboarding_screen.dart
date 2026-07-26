import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/brand/brand.dart';
import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../state/providers.dart';

/// First run, in two phases:
///
///  1. **Slides** — a swipeable intro with full-bleed photography, a Skip pill
///     floating over it, dots on the left and a pill button on the right.
///  2. **Methods** — create / import / sign in, over the brand halo.
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
    asset: 'assets/onboarding/onb_wallet.jpg',
    title: 'Meet your Omnia wallet',
    body: 'Universal Basic Compute, in your pocket. Check your balance, '
        'follow your activity, and carry your identity everywhere.',
  ),
  _Slide(
    asset: 'assets/onboarding/onb_keys.jpg',
    title: 'Your keys, your DID',
    body: 'Create a self-custody wallet whose keys never leave this device — '
        'or sign in with the Omnia account you already use on the web.',
  ),
  _Slide(
    asset: 'assets/onboarding/onb_send.jpg',
    title: 'Send. Vote. Take part.',
    body: 'Spend UBC in a couple of taps and have your say on governance '
        'proposals that steer the protocol.',
  ),
  _Slide(
    asset: 'assets/onboarding/onb_news.jpg',
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
    _pageController.nextPage(duration: Motion.normal, curve: Motion.enter);
  }

  Future<void> _create() async {
    Haptics.medium();
    setState(() => _busy = true);
    try {
      final mnemonic = await ref.read(authRepositoryProvider).createWallet();
      if (!mounted) return;
      final saved = await showOmniaSheet<bool>(
        context,
        title: 'Your recovery phrase',
        subtitle: 'Write these 12 words down in order and keep them offline. '
            'Anyone with this phrase controls your wallet — it is the only '
            'way to recover it.',
        dismissible: false,
        scrollable: true,
        initialSize: 0.78,
        builder: (_) => _RecoveryBody(mnemonic: mnemonic),
      );
      if (saved != true) return;
      _finish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final phrase = await showOmniaInput(
      context,
      title: 'Import a wallet',
      subtitle: 'Enter your 12-word recovery phrase, separated by spaces.',
      hintText: 'ability absent ocean …',
      confirmLabel: 'Import',
      maxLines: 3,
      validator: (v) {
        final words = v.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
        if (words.length != 12) return 'A recovery phrase is exactly 12 words';
        return null;
      },
    );
    if (phrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).importWallet(phrase);
      Haptics.success();
      _finish();
    } on FormatException catch (e) {
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: e.message, error: true);
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
      backgroundColor: context.omnia.bg,
      // No top SafeArea in the slides phase: the photo bleeds under the status
      // bar to the very top edge.
      body: AnimatedSwitcher(
        duration: Motion.normal,
        switchInCurve: Motion.enter,
        child: _showMethods
            ? SafeArea(child: _buildMethods(context))
            : _buildSlides(context),
      ),
    );
  }

  // ---- Phase 1: slides ----

  Widget _buildSlides(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final isLast = _index == _slides.length - 1;
    final imageHeight = MediaQuery.sizeOf(context).height * 0.48;

    return Stack(
      key: const ValueKey('slides'),
      children: [
        Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  // Throttled: a fast swipe fires this several times as the
                  // page settles, which without the throttle is a buzz.
                  Haptics.tick();
                  setState(() => _index = i);
                },
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(slide.asset, fit: BoxFit.cover),
                            // Dissolve the photo into the page so the text
                            // below sits on calm ground.
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.5, 1.0],
                                  colors: [Colors.transparent, o.bg],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: Space.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.title,
                              style: theme.textTheme.displaySmall,
                            ),
                            const SizedBox(height: Space.md),
                            Text(
                              slide.body,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: o.textMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Dots on the left, a pill button on the right.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xxl,
                  Space.sm,
                  Space.xl,
                  Space.lg,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: Motion.fast,
                        curve: Motion.standard,
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _index ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? o.accent : o.borderHigh,
                          borderRadius: Radii.rFull,
                        ),
                      ),
                    const Spacer(),
                    OmniaButton(
                      label: isLast ? 'Get started' : 'Next',
                      trailingIcon: isLast ? null : Iconsax.arrow_right_3_copy,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Skip: a frosted pill floating over the photo.
        Positioned(
          top: 0,
          right: Space.lg,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: Radii.rFull,
              child: _MaybeBlur(
                sigma: 14,
                child: Pressable(
                  onTap: _toMethods,
                  feel: PressFeel.subtle,
                  semanticLabel: 'Skip',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.sm,
                    ),
                    color: OmniaPalette.black
                        .withValues(alpha: kBlurEnabled ? 0.3 : 0.55),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: OmniaPalette.white,
                        fontWeight: Weights.semiBold,
                        fontSize: FontSizes.sm,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Phase 2: choose a method ----

  Widget _buildMethods(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      key: const ValueKey('methods'),
      padding: const EdgeInsets.fromLTRB(
        Space.xxl,
        Space.sm,
        Space.xxl,
        Space.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeIn(
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const BrandHalo(size: 260),
                  BrandMark(size: 76, color: o.text),
                ],
              ),
            ),
          ),
          FadeIn(
            delay: const Duration(milliseconds: 60),
            child: Text(
              'omnia',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: Space.sm),
          FadeIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'How would you like to start?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: o.textMedium),
            ),
          ),
          const SizedBox(height: Space.x4l),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(Space.lg),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            FadeIn(
              delay: const Duration(milliseconds: 140),
              child: MethodCard(
                icon: Iconsax.add_circle_copy,
                title: 'Create a new wallet',
                subtitle: 'Generate a fresh recovery phrase',
                primary: true,
                onTap: _create,
              ),
            ),
            const SizedBox(height: Space.md),
            FadeIn(
              delay: const Duration(milliseconds: 180),
              child: MethodCard(
                icon: Iconsax.import_1_copy,
                title: 'Import from recovery phrase',
                subtitle: 'Restore an existing wallet',
                onTap: _import,
              ),
            ),
            const SizedBox(height: Space.md),
            FadeIn(
              delay: const Duration(milliseconds: 220),
              child: MethodCard(
                icon: Iconsax.user_copy,
                title: 'Sign in with your Omnia account',
                subtitle: 'Google, GitHub, or email — from the web app',
                onTap: () => context.push('/signin'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Applies a backdrop blur, or passes the child straight through when
/// [kBlurEnabled] is off (see its documentation).
class _MaybeBlur extends StatelessWidget {
  const _MaybeBlur({required this.child, required this.sigma});

  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    if (!kBlurEnabled) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

/// A tappable "how do you want to start" option.
///
/// Shared with the sign-in screen. [leading] takes a real brand logo where one
/// exists; otherwise [icon] is drawn in the same slot.
class MethodCard extends StatelessWidget {
  const MethodCard({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  }) : assert(
          icon != null || leading != null,
          'Provide an icon or a custom leading widget',
        );

  final IconData? icon;

  /// Wins over [icon] — for a real brand mark.
  final Widget? leading;

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The recommended path: filled with the accent instead of outlined.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final fg = primary ? OmniaPalette.white : o.text;
    final sub =
        primary ? OmniaPalette.white.withValues(alpha: 0.82) : o.textLow;

    return Pressable(
      onTap: onTap,
      feel: PressFeel.firm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        decoration: BoxDecoration(
          color: primary ? o.accent : Colors.transparent,
          borderRadius: Radii.rLg,
          border: primary ? null : Border.all(color: o.borderMedium),
        ),
        child: Row(
          children: [
            leading ?? Icon(icon, color: fg, size: 22),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Icon(Iconsax.arrow_right_3_copy, size: 16, color: sub),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recovery phrase
// ---------------------------------------------------------------------------

/// The one screen in the app that must not be skimmed: 12 numbered words, a
/// copy affordance, and a confirmation checkbox that gates Continue.
class _RecoveryBody extends StatefulWidget {
  const _RecoveryBody({required this.mnemonic});

  final String mnemonic;

  @override
  State<_RecoveryBody> createState() => _RecoveryBodyState();
}

class _RecoveryBodyState extends State<_RecoveryBody> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final words = widget.mnemonic.split(' ');

    return SingleChildScrollView(
      primary: true,
      padding: sheetBodyPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (var i = 0; i < words.length; i++)
                _WordChip(index: i + 1, word: words[i]),
            ],
          ),
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: OmniaButton(
              label: 'Copy phrase',
              icon: Iconsax.copy_copy,
              size: ButtonSize.small,
              color: ButtonColor.secondary,
              onPressed: () {
                Haptics.warning();
                Clipboard.setData(ClipboardData(text: widget.mnemonic));
                showOmniaToast(
                  context,
                  message: 'Copied — clear your clipboard afterwards',
                );
              },
            ),
          ),
          const SizedBox(height: Space.xl),
          Pressable(
            onTap: () => setState(() => _confirmed = !_confirmed),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.micro,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _confirmed ? o.accent : Colors.transparent,
                    borderRadius: Radii.rXs,
                    border: Border.all(
                      color: _confirmed ? o.accent : o.borderHigh,
                      width: 1.5,
                    ),
                  ),
                  child: _confirmed
                      ? const Icon(
                          Iconsax.tick_circle,
                          size: 15,
                          color: OmniaPalette.white,
                        )
                      : null,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    'I have written down my recovery phrase',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: FontSizes.md,
                      color: o.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          OmniaButton(
            label: 'Continue',
            expand: true,
            onPressed: _confirmed
                ? () {
                    Haptics.success();
                    Navigator.of(context).pop(true);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.index, required this.word});

  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    // Three per row, computed against the sheet's own horizontal padding.
    final width =
        (MediaQuery.sizeOf(context).width - Space.xl * 2 - Space.sm * 2) / 3;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm + 2,
      ),
      decoration: BoxDecoration(
        color: o.bg25,
        borderRadius: Radii.rSm,
        border: Border.all(color: o.borderLow),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$index',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.xs,
                fontWeight: Weights.semiBold,
                color: o.textLow,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          Expanded(
            child: Text(
              word,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(fontSize: FontSizes.sm, color: o.text),
            ),
          ),
        ],
      ),
    );
  }
}
