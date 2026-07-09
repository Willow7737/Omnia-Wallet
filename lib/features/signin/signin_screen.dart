import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/method_card.dart';
import '../../data/supabase_gateway.dart';
import '../../state/providers.dart';

/// Mode B sign-in: use an existing Omnia account (created on the web app)
/// via Google, GitHub, or email + password. After Supabase authenticates,
/// the `mint-node-jwt` edge function links the account's DID and issues a
/// node JWT — no key material ever touches this device in this mode.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  StreamSubscription<void>? _authSub;
  bool _busy = false;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final gateway = ref.read(supabaseGatewayProvider);
    if (gateway.isAvailable) {
      // OAuth returns via deep link; the session shows up on this stream.
      _authSub = gateway.signedIn.listen((_) => _complete());
      // Already signed in to Supabase from a previous attempt? Finish the
      // DID/JWT link straight away.
      if (gateway.isSignedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Exchange the Supabase session for a node JWT + DID and enter the app.
  Future<void> _complete() async {
    if (_completing || !mounted) return;
    _completing = true;
    setState(() => _busy = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _social(SocialProvider provider) async {
    Haptics.medium();
    setState(() => _busy = true);
    try {
      await ref.read(supabaseGatewayProvider).signInWithSocial(provider);
      // The browser takes over; _complete() fires when the deep link returns.
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _email() async {
    Haptics.light();
    final creds = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _EmailDialog(),
    );
    if (creds == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseGatewayProvider)
          .signInWithEmail(email: creds.$1, password: creds.$2);
      await _complete();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = ref.watch(supabaseGatewayProvider).isAvailable;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text(
                  'Use the Omnia account you created on the web — your DID '
                  'and balance come with it.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
              if (!available)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Sign-in is unavailable in this build. Create or import '
                      'a self-custody wallet instead.',
                    ),
                  ),
                )
              else if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Linking your Omnia identity…'),
                      ],
                    ),
                  ),
                )
              else ...[
                FadeSlideIn(
                  delay: const Duration(milliseconds: 40),
                  child: MethodCard(
                    // The official "G" on a white chip so it reads correctly
                    // on the primary-colored card.
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/brand_icons/google_g.png',
                        width: 20,
                        height: 20,
                      ),
                    ),
                    title: 'Continue with Google',
                    subtitle: 'Opens your browser to sign in',
                    primary: true,
                    onTap: () => _social(SocialProvider.google),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: MethodCard(
                    // Official GitHub mark (solid) — tinted to match the
                    // theme in dark mode.
                    leading: Builder(builder: (context) {
                      final dark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Image.asset(
                        'assets/brand_icons/github_mark.png',
                        width: 26,
                        height: 26,
                        color: dark ? Colors.white : null,
                      );
                    }),
                    title: 'Continue with GitHub',
                    subtitle: 'Opens your browser to sign in',
                    primary: false,
                    onTap: () => _social(SocialProvider.github),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: MethodCard(
                    icon: Icons.alternate_email,
                    title: 'Email & password',
                    subtitle: 'The credentials you used on the web app',
                    primary: false,
                    onTap: _email,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'With account sign-in, transactions are authorized by the '
                  'Omnia server on your behalf. For full self-custody, create '
                  'a wallet with a recovery phrase instead.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog();

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in with email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_email.text.trim(), _password.text)),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}
