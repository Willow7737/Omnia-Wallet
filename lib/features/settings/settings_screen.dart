import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_mode.dart';
import '../../core/haptics.dart';
import '../lock/app_lock.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeUrl = ref.watch(nodeUrlProvider);
    final identityAsync = ref.watch(identityProvider);
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    final isSupabase = mode == AuthMode.supabase;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Identity'),
          identityAsync.when(
            loading: () => const ListTile(title: Text('Loading…')),
            error: (e, _) => ListTile(title: Text('Error: $e')),
            data: (identity) => ListTile(
              title: const Text('Your DID'),
              subtitle: Text(identity?.did ?? 'No wallet'),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: identity == null
                  ? null
                  : () {
                      Haptics.selection();
                      Clipboard.setData(ClipboardData(text: identity.did));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('DID copied')),
                      );
                    },
            ),
          ),
          const Divider(),
          const _SectionHeader('General'),
          ListTile(
            leading: const Icon(Icons.contacts_outlined),
            title: const Text('Address book'),
            subtitle: const Text('Saved recipient DIDs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/contacts'),
          ),
          const Divider(),
          const _SectionHeader('Node'),
          ListTile(
            title: const Text('Node endpoint'),
            subtitle: Text(nodeUrl),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editNodeUrl(context, ref, nodeUrl),
          ),
          const Divider(),
          const _SectionHeader('Security'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('App lock'),
            subtitle: const Text('Require biometrics to open the wallet'),
            value: ref.watch(appLockProvider.select((s) => s.enabled)),
            onChanged: (v) => _toggleAppLock(context, ref, v),
          ),
          // Supabase accounts have no on-device key, so no phrase to reveal.
          if (!isSupabase)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Reveal recovery phrase'),
              onTap: () => _revealPhrase(context, ref),
            ),
          ListTile(
            leading: Icon(isSupabase ? Icons.logout : Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text(
                isSupabase ? 'Sign out' : 'Remove wallet from this device',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _wipe(context, ref, isSupabase: isSupabase),
          ),
          const Divider(),
          const _SectionHeader('Advanced'),
          ListTile(
            leading: const Icon(Icons.lan_outlined),
            title: const Text('Network'),
            subtitle: const Text('Node status, version, peers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/network'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    final result = await ref.read(appLockProvider.notifier).setEnabled(enable);
    if (!context.mounted) return;
    switch (result) {
      case UnlockResult.success:
        Haptics.selection();
      case UnlockResult.failed:
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
      case UnlockResult.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrics are not available on this device'),
          ),
        );
    }
  }

  Future<void> _editNodeUrl(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Node endpoint'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'http://host:9090'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await ref.read(secureStoreProvider).saveNodeUrl(url);
    ref.read(nodeUrlProvider.notifier).state = url;
    ref.invalidate(balanceProvider);
    ref.invalidate(historyProvider);
  }

  Future<void> _revealPhrase(BuildContext context, WidgetRef ref) async {
    final mnemonic = await ref.read(secureStoreProvider).readMnemonic();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recovery phrase'),
        content: SelectableText(
          mnemonic ?? 'Not available',
          style: const TextStyle(fontFamily: 'monospace', height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref,
      {required bool isSupabase}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isSupabase ? 'Sign out?' : 'Remove wallet?'),
        content: Text(
          isSupabase
              ? 'This signs you out on this device. Your DID and balance stay '
                  'with your account — sign back in any time.'
              : 'This deletes your keys from this device. You can only restore '
                  'the wallet with your recovery phrase. Make sure it is '
                  'backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isSupabase ? 'Sign out' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(hasWalletProvider);
    ref.invalidate(identityProvider);
    ref.invalidate(authModeProvider);
    if (context.mounted) context.go('/onboarding');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
