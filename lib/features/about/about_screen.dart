import 'package:flutter/material.dart';

/// Plain-language "What is this?" explainer, written for someone who has
/// never heard of Omnia, DIDs, or distributed ledgers.
///
/// Reachable from Settings → What is Omnia?. Deliberately concrete about the
/// two behaviours that most often read as bugs to a newcomer: a UBC transfer
/// *spends* the amount without crediting the recipient, and the
/// "Final · Lane 0" badge on a transaction. Getting those explained up front
/// prevents the "where did my UBC go?" support question.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('What is Omnia?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Omnia in 30 seconds',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Omnia is an open network — a shared record that no company owns. '
            'This app is your way into it, and it does two things: it gives '
            'you an identity that is genuinely yours, and a monthly compute '
            'allowance called UBC for using the network.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'There is no signup form and no password — because nothing about '
            'you is stored on our servers.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          const _Topic(
            icon: Icons.key_outlined,
            title: 'Your identity lives on your phone',
            body: 'When you first opened the app, your phone created a private '
                'key and locked it in secure hardware. From it you get a '
                'public ID (your DID) that you can share freely.\n\n'
                'We never see your key, so we can never freeze or reset your '
                'identity. The flip side is real: write down your recovery '
                'phrase. Without it, a lost phone means a lost identity — and '
                'nobody, including us, can restore it.',
          ),
          const _Topic(
            icon: Icons.speed_outlined,
            title: 'UBC is your compute allowance',
            body: 'Every identity receives 1,000 UBC (Universal Basic Compute) '
                'each month, automatically. It is your budget for doing things '
                'on the network. Everyone gets the same amount — you do not '
                'earn it, mine it, or buy it.',
          ),
          const _Callout(
            icon: Icons.info_outlined,
            title: 'Important: UBC is not money',
            lines: [
              'You cannot buy UBC — it has no price.',
              'You cannot sell or trade it — there is no exchange.',
              'It has no monetary value and is not an investment.',
            ],
            footer:
                'Think of it like the data allowance on a phone plan: useful '
                'for doing things, not something you would try to sell.',
          ),
          const _Topic(
            icon: Icons.local_fire_department_outlined,
            title: 'Sending UBC spends it — the recipient is not credited',
            body: 'This surprises everyone at first, and it is intentional. '
                'Sending UBC subtracts it from your allowance and records the '
                'recipient’s ID as a permanent, public note that you sent '
                'it to them. Their balance does not go up.\n\n'
                'It is a receipt, not a payment. This is exactly why UBC can '
                'never be hoarded or turned into wealth.',
          ),
          const _Topic(
            icon: Icons.bolt_outlined,
            title: 'What "Final · Lane 0" means',
            body:
                'It tells you how settled a transaction is. Lane 0 is the fast '
                'confirmation — a group of validators cryptographically signed '
                'off within moments. Lane 1 is the slower, permanent '
                'settlement.\n\n'
                'Most apps hide this behind a spinner. We show it so you always '
                'know exactly where a transaction stands.',
          ),
          const _Topic(
            icon: Icons.science_outlined,
            title: 'This is early access',
            body:
                'The app runs against a test network, so balances and history '
                'are for testing and may be reset. Expect rough edges — and '
                'please tell us about them, especially anything that felt '
                'confusing or made you nervous. That is the most useful '
                'feedback there is.',
          ),
          const SizedBox(height: 8),
          Text(
            'You can read the full community guidelines under Settings → '
            'Safety.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Topic extends StatelessWidget {
  const _Topic({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.title,
    required this.lines,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 9),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            footer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
