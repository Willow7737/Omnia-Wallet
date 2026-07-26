import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/theme.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/states.dart';

/// Plain-language "What is this?" explainer, written for someone who has never
/// heard of Omnia, DIDs, or distributed ledgers.
///
/// Deliberately concrete about the two behaviours that most often read as bugs
/// to a newcomer: a UBC transfer *spends* the amount without crediting the
/// recipient, and the "Final · Lane 0" badge on a transaction. Explaining those
/// up front prevents the "where did my UBC go?" support question.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'What is Omnia?'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x4l),
        children: [
          // ---- lede ----
          FadeIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xl,
                Space.lg,
                Space.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Omnia in 30 seconds',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    'Omnia is an open network — a shared record that no company '
                    'owns. This app is your way into it, and it does two '
                    'things: it gives you an identity that is genuinely yours, '
                    'and a monthly compute allowance called UBC for using the '
                    'network.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: o.textMedium),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    'There is no signup form and no password — because nothing '
                    'about you is stored on our servers.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: o.textMedium),
                  ),
                ],
              ),
            ),
          ),
          const Hairline(),

          const _Topic(
            icon: Iconsax.key_copy,
            title: 'Your identity lives on your phone',
            body: 'When you first opened the app, your phone created a private '
                'key and locked it in secure hardware. From it you get a '
                'public ID (your DID) that you can share freely.\n\n'
                'We never see your key, so we can never freeze or reset your '
                'identity. The flip side is real: write down your recovery '
                'phrase. Without it, a lost phone means a lost identity — and '
                'nobody, including us, can restore it.',
          ),
          const Hairline(indent: Space.lg),
          const _Topic(
            icon: Iconsax.flash_1_copy,
            title: 'UBC is your compute allowance',
            body: 'Every identity receives 1,000 UBC (Universal Basic Compute) '
                'each month, automatically. It is your budget for doing things '
                'on the network. Everyone gets the same amount — you do not '
                'earn it, mine it, or buy it.',
          ),

          // The single most important correction in the whole screen, so it
          // gets the one filled surface on the page.
          const _Callout(
            title: 'Important: UBC is not money',
            lines: [
              'You cannot buy UBC — it has no price.',
              'You cannot sell or trade it — there is no exchange.',
              'It has no monetary value and is not an investment.',
            ],
            footer: 'Think of it like the data allowance on a phone plan: '
                'useful for doing things, not something you would try to sell.',
          ),

          const Hairline(),
          const _Topic(
            icon: Iconsax.arrow_up_3_copy,
            title: 'Sending UBC spends it — the recipient is not credited',
            body: 'This surprises everyone at first, and it is intentional. '
                'Sending UBC subtracts it from your allowance and records the '
                'recipient’s ID as a permanent, public note that you sent it '
                'to them. Their balance does not go up.\n\n'
                'It is a receipt, not a payment. This is exactly why UBC can '
                'never be hoarded or turned into wealth.',
          ),
          const Hairline(indent: Space.lg),
          const _Topic(
            icon: Iconsax.flash_1,
            title: 'What “Final · Lane 0” means',
            body: 'It tells you how settled a transaction is. Lane 0 is the '
                'fast confirmation — a group of validators cryptographically '
                'signed off within moments. Lane 1 is the slower, permanent '
                'settlement.\n\n'
                'Most apps hide this behind a spinner. We show it so you '
                'always know exactly where a transaction stands.',
          ),
          const Hairline(indent: Space.lg),
          const _Topic(
            icon: Iconsax.cpu_copy,
            title: 'This is early access',
            body: 'The app runs against a test network, so balances and '
                'history are for testing and may be reset. Expect rough edges '
                '— and please tell us about them, especially anything that '
                'felt confusing or made you nervous. That is the most useful '
                'feedback there is.',
          ),
          const Hairline(),

          OmniaRow(
            title: 'Community guidelines',
            subtitle: 'What is and isn’t allowed on the network',
            icon: Iconsax.shield_tick_copy,
            chevron: true,
            onTap: () => context.push('/safety'),
          ),
        ],
      ),
    );
  }
}

/// One explainer section: a tinted glyph, a heading, and prose indented to
/// clear the glyph so the column of text reads as one measure.
class _Topic extends StatelessWidget {
  const _Topic({required this.icon, required this.title, required this.body});

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
        vertical: Space.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconAvatar(icon: icon, tint: o.accent, size: 34, iconSize: 16),
              const SizedBox(width: Space.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.title,
    required this.lines,
    required this.footer,
  });

  final String title;
  final List<String> lines;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: o.accent.withValues(alpha: 0.08),
        borderRadius: Radii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle_copy, size: 18, color: o.accent),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: o.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    // Optically centred against the first line of text rather
                    // than its box, which sits a couple of pixels higher.
                    margin: const EdgeInsets.only(top: 8, right: Space.sm + 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: o.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: o.textHigh),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.xs),
          Text(
            footer,
            style: theme.textTheme.bodySmall?.copyWith(color: o.textMedium),
          ),
        ],
      ),
    );
  }
}
