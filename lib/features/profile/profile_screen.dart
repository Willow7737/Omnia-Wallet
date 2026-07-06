import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/identicon.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../state/providers.dart';

/// The user's identity at a glance: a generated identicon avatar, an editable
/// display name (local only), and the DID with quick actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);
    final displayName = ref.watch(displayNameProvider).valueOrNull;
    final email = ref.watch(supabaseEmailProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (identity) {
          if (identity == null) {
            return const Center(child: Text('No wallet found'));
          }
          final name = (displayName == null || displayName.isEmpty)
              ? Fmt.shortDid(identity.did)
              : displayName;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FadeSlideIn(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Identicon(seed: identity.did, size: 96),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () =>
                          _editName(context, ref, displayName ?? ''),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                        displayName == null || displayName.isEmpty
                            ? 'Set a display name'
                            : 'Edit name',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    if (email != null) ...[
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Signed in as'),
                        subtitle: Text(email),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('DID'),
                      subtitle: Text(identity.did),
                      trailing: const Icon(Icons.copy, size: 18),
                      onTap: () {
                        Haptics.selection();
                        Clipboard.setData(ClipboardData(text: identity.did));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('DID copied')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: const Text('Show QR'),
                      onTap: () {
                        Haptics.light();
                        context.push('/receive');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      onTap: () {
                        Haptics.light();
                        context.push('/settings');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'How should we call you?'),
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
    if (name == null) return;
    await ref.read(secureStoreProvider).saveDisplayName(name);
    ref.invalidate(displayNameProvider);
    if (context.mounted) Haptics.selection();
  }
}
