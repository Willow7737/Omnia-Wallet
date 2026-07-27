import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/brand/brand.dart';
import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../data/supabase_gateway.dart';
import '../../state/providers.dart';
import '../onboarding/onboarding_screen.dart' show MethodCard;

/// Mode B sign-in: use an existing Omnia account (created on the web app) via
/// Google, GitHub, or email + password.
///
/// After Supabase authenticates, the `mint-node-jwt` edge function links the
/// account's DID and issues a node JWT — no key material ever touches this
/// device in this mode.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _authSub;
  bool _busy = false;
  bool _completing = false;

  /// True from the moment the browser is opened until the round trip ends.
  ///
  /// The screen has to stay in a waiting state across that gap. Clearing it
  /// as soon as the browser launched left the reader looking at the sign-in
  /// buttons again on their return, with no sign anything had happened — so
  /// they tapped a second time, which is what actually completed it.
  bool _awaitingBrowser = false;
  Timer? _awaitTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final gateway = ref.read(supabaseGatewayProvider);
    if (gateway.isAvailable) {
      // OAuth returns via deep link; the session shows up on this stream.
      _authSub = gateway.signedIn.listen((_) => _complete());
      // Already signed in from a previous attempt? Finish the DID/JWT link
      // straight away.
      if (gateway.isSignedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
      }
    }
  }

  @override
  void dispose() {
    _awaitTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  /// Coming back from the browser is the other half of the sign-in.
  ///
  /// The stream is not enough on its own: if the app was evicted while
  /// backgrounded, the session is restored during startup and that event has
  /// already been and gone by the time this screen subscribes. Checking on
  /// resume covers the case the stream cannot.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingBrowser) return;

    // The deep link is handled a beat after resume, so give it one.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !_awaitingBrowser) return;
      if (ref.read(supabaseGatewayProvider).isSignedIn) {
        _complete();
      }
    });
  }

  void _startAwaiting() {
    _awaitTimeout?.cancel();
    setState(() => _awaitingBrowser = true);
    // If the reader backed out of the browser without signing in, nothing
    // will ever arrive. Give up rather than spin forever.
    _awaitTimeout = Timer(const Duration(seconds: 90), () {
      if (mounted && _awaitingBrowser && !_completing) {
        setState(() => _awaitingBrowser = false);
      }
    });
  }

  void _stopAwaiting() {
    _awaitTimeout?.cancel();
    if (mounted && _awaitingBrowser) setState(() => _awaitingBrowser = false);
  }

  /// Exchange the Supabase session for a node JWT + DID and enter the app.
  Future<void> _complete() async {
    if (_completing || !mounted) return;
    _completing = true;
    _awaitTimeout?.cancel();
    setState(() {
      _awaitingBrowser = false;
      _busy = true;
    });
    try {
      await ref.read(authRepositoryProvider).completeSupabaseSignIn();
      ref.invalidate(hasWalletProvider);
      ref.invalidate(identityProvider);
      ref.invalidate(authModeProvider);
      if (!mounted) return;
      Haptics.success();
      context.go('/');
    } catch (e) {
      _completing = false;
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _social(SocialProvider provider) async {
    Haptics.medium();
    _startAwaiting();
    try {
      await ref.read(supabaseGatewayProvider).signInWithSocial(provider);
      // The browser takes over. The waiting state stays up until the deep
      // link returns, the app resumes with a session, or the timeout gives
      // up — never cleared here, which was the bug.
    } catch (e) {
      _stopAwaiting();
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  Future<void> _email() async {
    final email = await showOmniaInput(
      context,
      title: 'Sign in with email',
      subtitle: 'The address you used on the web app.',
      hintText: 'you@example.com',
      confirmLabel: 'Next',
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
          v.contains('@') && v.contains('.') ? null : 'Enter a valid email',
    );
    if (email == null || email.isEmpty || !mounted) return;

    final password = await showOmniaInput(
      context,
      title: 'Password',
      subtitle: email,
      confirmLabel: 'Sign in',
      obscure: true,
      validator: (v) => v.isEmpty ? 'Enter your password' : null,
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseGatewayProvider)
          .signInWithEmail(email: email, password: password);
      await _complete();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final available = ref.watch(supabaseGatewayProvider).isAvailable;

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Sign in'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.xxl,
            Space.lg,
            Space.xxl,
            Space.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeIn(
                child: Text(
                  'Use the Omnia account you created on the web — your DID '
                  'and balance come with it.',
                  style:
                      theme.textTheme.bodyLarge?.copyWith(color: o.textMedium),
                ),
              ),
              const SizedBox(height: Space.xxl),
              if (!available)
                _Unavailable()
              else if (_busy || _awaitingBrowser)
                _Waiting(
                  message: _busy
                      ? 'Linking your Omnia identity…'
                      : 'Waiting for you to finish in the browser…',
                  // Only offer a way out of the browser wait; the linking
                  // step is short and cancelling it mid-way would leave the
                  // account half-attached.
                  onCancel: _busy ? null : _stopAwaiting,
                )
              else ...[
                FadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: MethodCard(
                    // Google's "G" keeps its brand colours, on a white chip so
                    // it reads correctly against the accent-filled card.
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: OmniaPalette.white,
                        shape: BoxShape.circle,
                      ),
                      child: const BrandIcon.google(size: 18),
                    ),
                    title: 'Continue with Google',
                    subtitle: 'Opens your browser to sign in',
                    primary: true,
                    onTap: () => _social(SocialProvider.google),
                  ),
                ),
                const SizedBox(height: Space.md),
                FadeIn(
                  delay: const Duration(milliseconds: 80),
                  child: MethodCard(
                    // GitHub's mark is monochrome by design, so it takes the
                    // theme's text colour rather than staying black.
                    leading: BrandIcon.github(size: 22, tint: o.text),
                    title: 'Continue with GitHub',
                    subtitle: 'Opens your browser to sign in',
                    onTap: () => _social(SocialProvider.github),
                  ),
                ),
                const SizedBox(height: Space.md),
                FadeIn(
                  delay: const Duration(milliseconds: 120),
                  child: MethodCard(
                    icon: Iconsax.sms_copy,
                    title: 'Email & password',
                    subtitle: 'The credentials you used on the web app',
                    onTap: _email,
                  ),
                ),
                const SizedBox(height: Space.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.info_circle_copy, size: 16, color: o.textLow),
                    const SizedBox(width: Space.md - 2),
                    Expanded(
                      child: Text(
                        'With account sign-in, transactions are authorized by '
                        'the Omnia server on your behalf. For full '
                        'self-custody, create a wallet with a recovery phrase '
                        'instead.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: o.textLow),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The waiting state: a spinner, what is being waited on, and — when the
/// wait depends on something happening in another app — a way out.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.message, this.onCancel});

  final String message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x4l),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: Space.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: FontSizes.md,
              color: o.textMedium,
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(height: Space.lg),
            OmniaTextButton(label: 'Cancel', onTap: onCancel),
          ],
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OmniaEmptyState(
      icon: Iconsax.slash_copy,
      title: 'Sign-in unavailable',
      message: 'This build has no account backend configured. Create or '
          'import a self-custody wallet instead.',
      actionLabel: 'Go back',
      onAction: () => Navigator.of(context).maybePop(),
    );
  }
}
