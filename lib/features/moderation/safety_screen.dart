import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../state/blocklist.dart';

/// Safety & moderation hub: the community guidelines that govern user-
/// generated content, plus management of the accounts this device has
/// blocked. Reachable from Settings → Safety.
///
/// Blocking is client-side only — blocked identifiers live in secure storage
/// on this device and hide an author's posts and replies from this user's
/// feed. Reports, by contrast, are sent to the moderation team.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocked = ref.watch(blocklistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        children: [
          const _SectionHeader('Community guidelines'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Omnia is a space for builders. Keep it useful and kind — these '
              'rules apply everywhere you can post or reply.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
          const _Guideline(
            icon: Icons.handshake_outlined,
            title: 'Be respectful',
            body: 'No harassment, bullying, hate speech, or threats. Attack '
                'ideas, never people.',
          ),
          const _Guideline(
            icon: Icons.block_flipped,
            title: 'No spam or scams',
            body:
                'Don’t post unsolicited promotions, phishing links, giveaways, '
                'or attempts to steal keys, funds, or recovery phrases.',
          ),
          const _Guideline(
            icon: Icons.shield_outlined,
            title: 'Keep it safe for everyone',
            body: 'No sexual, explicit, or graphically violent content, and '
                'nothing that endangers anyone.',
          ),
          const _Guideline(
            icon: Icons.verified_user_outlined,
            title: 'Be honest',
            body: 'Don’t impersonate others or spread deliberate '
                'misinformation.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Reports are reviewed within 24 hours. Content that breaks these '
              'rules is removed, and repeat offenders lose access. You can '
              'report or block any author from the “···” menu on their reply.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Blocked accounts'),
          if (blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'You haven’t blocked anyone. Blocked accounts are hidden from '
                'your feed and can be unblocked here at any time.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final key in blocked)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(_labelFor(key)),
                trailing: TextButton(
                  onPressed: () async {
                    Haptics.selection();
                    await ref.read(blocklistProvider.notifier).unblock(key);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked ${_labelFor(key)}')),
                      );
                    }
                  },
                  child: const Text('Unblock'),
                ),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Turn a stored block key (`uid:…` / `name:…`) into a readable label.
  static String _labelFor(String key) {
    if (key.startsWith('name:')) return key.substring(5);
    if (key.startsWith('uid:')) return 'Account ${key.substring(4, 12)}…';
    return key;
  }
}

class _Guideline extends StatelessWidget {
  const _Guideline({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(body,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      isThreeLine: true,
    );
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
