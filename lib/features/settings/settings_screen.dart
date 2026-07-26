import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/auth_mode.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../lock/app_lock.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final nodeUrl = ref.watch(nodeUrlProvider);
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    final isSupabase = mode == AuthMode.supabase;
    final hapticsOn = ref.watch(hapticsEnabledProvider);
    final appLockOn = ref.watch(appLockProvider.select((s) => s.enabled));

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x4l),
        children: [
          const OmniaSectionLabel('Appearance'),
          const _ThemePicker(),
          const Hairline(),

          const OmniaSectionLabel('Feedback'),
          OmniaSwitchRow(
            title: 'Haptics',
            subtitle: 'Vibrate on taps, confirmations and errors',
            icon: Iconsax.mobile_copy,
            value: hapticsOn,
            onChanged: (v) => ref.read(hapticsEnabledProvider.notifier).set(v),
          ),
          const Hairline(),

          const OmniaSectionLabel('Security'),
          OmniaSwitchRow(
            title: 'App lock',
            subtitle: 'Require biometrics to open the wallet',
            icon: Iconsax.finger_scan_copy,
            value: appLockOn,
            onChanged: (v) => _toggleAppLock(context, ref, v),
          ),
          // Supabase accounts have no on-device key, so there is no phrase to
          // reveal.
          if (!isSupabase) ...[
            const Hairline(indent: Space.lg),
            OmniaRow(
              title: 'Reveal recovery phrase',
              subtitle: 'The 12 words that restore this wallet',
              icon: Iconsax.key_copy,
              chevron: true,
              onTap: () => _revealPhrase(context, ref),
            ),
          ],
          const Hairline(),

          const OmniaSectionLabel('Network'),
          OmniaRow(
            title: 'Node endpoint',
            subtitle: nodeUrl,
            icon: Iconsax.global_copy,
            trailingIcon: Iconsax.edit_2_copy,
            onTap: () => _editNodeUrl(context, ref, nodeUrl),
          ),
          const Hairline(indent: Space.lg),
          OmniaRow(
            title: 'Node status',
            subtitle: 'Version, peers, reachability',
            icon: Iconsax.status_up_copy,
            chevron: true,
            onTap: () => context.push('/network'),
          ),
          const Hairline(),

          const OmniaSectionLabel('Account'),
          OmniaRow(
            title: isSupabase ? 'Sign out' : 'Remove wallet from this device',
            subtitle: isSupabase
                ? 'Your DID and balance stay with your account'
                : 'Recoverable only with your recovery phrase',
            icon: isSupabase ? Iconsax.logout_copy : Iconsax.trash_copy,
            destructive: true,
            onTap: () => _wipe(context, ref, isSupabase: isSupabase),
          ),
          const Hairline(),

          const _VersionFooter(),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final result = await ref.read(appLockProvider.notifier).setEnabled(enable);
    if (!context.mounted) return;
    switch (result) {
      case UnlockResult.success:
        Haptics.selection();
      case UnlockResult.failed:
        Haptics.error();
        showOmniaToast(context, message: 'Authentication failed', error: true);
      case UnlockResult.unavailable:
        showOmniaToast(
          context,
          message: 'Biometrics are not available on this device',
          error: true,
        );
    }
  }

  Future<void> _editNodeUrl(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final url = await showOmniaInput(
      context,
      title: 'Node endpoint',
      subtitle: 'The Omnia node this wallet talks to.',
      initialValue: current,
      hintText: 'https://node.example.com',
      keyboardType: TextInputType.url,
      validator: (v) {
        if (v.isEmpty) return 'Enter a node URL';
        final uri = Uri.tryParse(v);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          return 'Enter a full URL, including https://';
        }
        return null;
      },
    );
    if (url == null || url.isEmpty) return;

    await ref.read(secureStoreProvider).saveNodeUrl(url);
    ref.read(nodeUrlProvider.notifier).state = url;
    ref.invalidate(balanceProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(nodeInfoProvider);
    if (context.mounted) {
      showOmniaToast(context, message: 'Node endpoint updated');
    }
  }

  Future<void> _revealPhrase(BuildContext context, WidgetRef ref) async {
    // Confirm before revealing: a recovery phrase on screen is the single most
    // dangerous thing this app can display, and it should never appear from a
    // stray tap.
    final proceed = await showOmniaConfirm(
      context,
      icon: Iconsax.key_copy,
      title: 'Reveal recovery phrase?',
      message: 'Make sure nobody can see your screen. Anyone with these 12 '
          'words controls your wallet.',
      confirmLabel: 'Reveal',
    );
    if (!proceed || !context.mounted) return;

    final mnemonic = await ref.read(secureStoreProvider).readMnemonic();
    if (!context.mounted) return;

    await showOmniaSheet<void>(
      context,
      title: 'Recovery phrase',
      subtitle: 'Write these down in order and keep them offline.',
      builder: (sheetContext) => _RecoveryPhraseBody(mnemonic: mnemonic),
    );
  }

  Future<void> _wipe(
    BuildContext context,
    WidgetRef ref, {
    required bool isSupabase,
  }) async {
    final confirmed = await showOmniaConfirm(
      context,
      icon: isSupabase ? Iconsax.logout_copy : Iconsax.trash_copy,
      title: isSupabase ? 'Sign out?' : 'Remove wallet?',
      message: isSupabase
          ? 'This signs you out on this device. Your DID and balance stay '
              'with your account — sign back in any time.'
          : 'This deletes your keys from this device. You can only restore '
              'the wallet with your recovery phrase. Make sure it is backed up.',
      confirmLabel: isSupabase ? 'Sign out' : 'Remove wallet',
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(hasWalletProvider);
    ref.invalidate(identityProvider);
    ref.invalidate(authModeProvider);
    if (context.mounted) context.go('/onboarding');
  }
}

// ---------------------------------------------------------------------------
// Theme picker
// ---------------------------------------------------------------------------

/// Light / Dim / Dark, as three tappable swatches.
///
/// A swatch preview is worth more than three words in a menu: "Dim" means
/// nothing until you see that it is a soft blue-grey rather than black.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xl),
      child: Row(
        children: [
          for (final name in OmniaThemeName.values) ...[
            Expanded(
              child: _ThemeSwatch(
                name: name,
                selected: name == active,
                onTap: () {
                  Haptics.selection();
                  ref.read(themeProvider.notifier).set(name);
                },
              ),
            ),
            if (name != OmniaThemeName.values.last)
              const SizedBox(width: Space.md),
          ],
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final OmniaThemeName name;
  final bool selected;
  final VoidCallback onTap;

  /// The page colour each theme would produce, read straight off the token
  /// tables so the preview can never drift from the real thing.
  ({Color bg, Color fg, Color muted}) get _preview {
    final palette = switch (name) {
      OmniaThemeName.light => OmniaPalette.defaults,
      OmniaThemeName.dim => OmniaPalette.subdued.invert(),
      OmniaThemeName.dark => OmniaPalette.defaults.invert(),
    };
    return (
      bg: palette.contrast0,
      fg: palette.contrast1000,
      muted: palette.contrast200,
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final p = _preview;

    return Pressable(
      onTap: onTap,
      haptic: false,
      semanticLabel: '${name.label} theme',
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 76,
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: Radii.rMd,
              border: Border.all(
                color: selected ? o.accent : o.borderMedium,
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 6,
                  width: 34,
                  decoration: BoxDecoration(
                    color: p.fg,
                    borderRadius: Radii.rFull,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Container(
                  height: 5,
                  width: 48,
                  decoration: BoxDecoration(
                    color: p.muted,
                    borderRadius: Radii.rFull,
                  ),
                ),
                const SizedBox(height: Space.xs + 1),
                Container(
                  height: 5,
                  width: 28,
                  decoration: BoxDecoration(
                    color: p.muted,
                    borderRadius: Radii.rFull,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            name.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: FontSizes.sm,
              fontWeight: selected ? Weights.bold : Weights.medium,
              color: selected ? o.text : o.textLow,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recovery phrase
// ---------------------------------------------------------------------------

class _RecoveryPhraseBody extends StatelessWidget {
  const _RecoveryPhraseBody({required this.mnemonic});

  final String? mnemonic;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final phrase = mnemonic;

    if (phrase == null || phrase.isEmpty) {
      return Padding(
        padding: sheetBodyPadding(context),
        child: Text(
          'No recovery phrase is stored on this device.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.md,
            color: o.textMedium,
          ),
        ),
      );
    }

    final words = phrase.split(' ');
    return SingleChildScrollView(
      padding: sheetBodyPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Numbered, in a two-column grid — the order is part of the secret,
          // so it has to be unmistakable.
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (var i = 0; i < words.length; i++)
                _Word(index: i + 1, word: words[i]),
            ],
          ),
          const SizedBox(height: Space.xl),
          OmniaRow(
            title: 'Copy to clipboard',
            subtitle: 'Clear your clipboard afterwards',
            icon: Iconsax.copy_copy,
            onTap: () {
              Haptics.warning();
              Clipboard.setData(ClipboardData(text: phrase));
              showOmniaToast(context, message: 'Recovery phrase copied');
            },
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.index, required this.word});

  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      width: (MediaQuery.sizeOf(context).width - Space.xl * 2 - Space.sm * 2) / 3,
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

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.xxl,
      ),
      child: Center(
        child: Text(
          'Omnia Wallet',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.sm,
            color: o.textLow,
          ),
        ),
      ),
    );
  }
}
