import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/sheet.dart';
import '../../state/blocklist.dart';

/// Safety & moderation hub: the community guidelines that govern user
/// generated content, plus management of the accounts this device has blocked.
///
/// Blocking is client-side only — blocked identifiers live in secure storage
/// on this device and hide an author's posts and replies from this user's
/// feed. Reports, by contrast, are sent to the moderation team.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  static const _guidelines = <({IconData icon, String title, String body})>[
    (
      icon: Iconsax.people_copy,
      title: 'Be respectful',
      body: 'No harassment, bullying, hate speech, or threats. Attack ideas, '
          'never people.',
    ),
    (
      icon: Iconsax.slash_copy,
      title: 'No spam or scams',
      body: 'Don’t post unsolicited promotions, phishing links, '
          'giveaways, or attempts to steal keys, funds, or recovery phrases.',
    ),
    (
      icon: Iconsax.shield_tick_copy,
      title: 'Keep it safe for everyone',
      body: 'No sexual, explicit, or graphically violent content, and nothing '
          'that endangers anyone.',
    ),
    (
      icon: Iconsax.verify_copy,
      title: 'Be honest',
      body: 'Don’t impersonate others or spread deliberate '
          'misinformation.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final blocked = ref.watch(blocklistProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Safety'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x4l),
        children: [
          const OmniaSectionLabel('Community guidelines'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              0,
              Space.lg,
              Space.md,
            ),
            child: Text(
              'Omnia is a space for builders. Keep it useful and kind — these '
              'rules apply everywhere you can post or reply.',
              style: theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
            ),
          ),
          for (final g in _guidelines)
            _Guideline(icon: g.icon, title: g.title, body: g.body),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.lg,
            ),
            child: Text(
              'Reports are reviewed within 24 hours. Content that breaks these '
              'rules is removed, and repeat offenders lose access. You can '
              'report or block any author from the “···” menu on their reply.',
              style: theme.textTheme.bodySmall?.copyWith(color: o.textLow),
            ),
          ),
          const Hairline(),

          OmniaSectionLabel(
            'Blocked accounts',
            action: blocked.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Text(
                      '${blocked.length}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.xs,
                        fontWeight: Weights.bold,
                        color: o.textLow,
                      ),
                    ),
                  ),
          ),
          if (blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              child: Text(
                'You haven’t blocked anyone. Blocked accounts are hidden '
                'from your feed and can be unblocked here at any time.',
                style: theme.textTheme.bodySmall?.copyWith(color: o.textLow),
              ),
            )
          else
            for (final key in blocked) _BlockedRow(blockKey: key),
        ],
      ),
    );
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
    final o = context.omnia;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconAvatar(icon: icon, tint: o.accent, size: 36, iconSize: 17),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: o.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedRow extends ConsumerWidget {
  const _BlockedRow({required this.blockKey});

  final String blockKey;

  /// Turn a stored block key (`uid:…` / `name:…`) into a readable label.
  static String labelFor(String key) {
    if (key.startsWith('name:')) return key.substring(5);
    if (key.startsWith('uid:')) {
      final id = key.substring(4);
      return 'Account ${id.length > 8 ? '${id.substring(0, 8)}…' : id}';
    }
    return key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = labelFor(blockKey);
    return OmniaRow(
      title: label,
      subtitle: 'Hidden from your feed',
      leading: DidAvatar(did: blockKey, size: 36),
      trailing: OmniaButton(
        label: 'Unblock',
        size: ButtonSize.tiny,
        color: ButtonColor.secondary,
        onPressed: () async {
          Haptics.selection();
          await ref.read(blocklistProvider.notifier).unblock(blockKey);
          if (context.mounted) {
            showOmniaToast(context, message: 'Unblocked $label');
          }
        },
      ),
    );
  }
}
