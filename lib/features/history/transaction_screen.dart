import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Everything about one transfer: direction, amount, parties, timing, id.
class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key, required this.record});

  final TransferRecord record;

  void _copy(BuildContext context, String label, String value) {
    Haptics.selection();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final omnia = context.omnia;
    final myDid = ref.watch(identityProvider).valueOrNull?.did;
    final mine = myDid != null && record.fromDid == myDid;

    final tint = mine ? omnia.negative : scheme.onSurfaceVariant;
    final ok = record.status.toLowerCase() == 'completed' ||
        record.status.toLowerCase() == 'success';

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          FadeSlideIn(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: tint.withValues(alpha: 0.14),
                  child: Icon(
                    mine ? Icons.arrow_upward : Icons.swap_horiz,
                    color: tint,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  mine ? '−${Fmt.ubc(record.amount)}' : Fmt.ubc(record.amount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: mine ? omnia.negative : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Status + provenance chips.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: record.status.isEmpty ? 'recorded' : record.status,
                      color: ok ? omnia.success : omnia.warning,
                    ),
                    // Lane 0 fast-path finality (only when the node tracks it).
                    if (record.lane0Final != null)
                      _Chip(
                        label: record.lane0Final!
                            ? 'Final · Lane 0'
                            : 'Awaiting finality',
                        color: record.lane0Final! ? omnia.success : tint,
                        icon: record.lane0Final!
                            ? Icons.bolt
                            : Icons.hourglass_empty,
                      ),
                    // On-device signature (self-sovereign spend).
                    if (record.isWalletSigned)
                      _Chip(
                        label: 'Signed on-device',
                        color: scheme.primary,
                        icon: Icons.verified_user_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: Card(
              child: Column(
                children: [
                  _Row(
                    label: 'From',
                    value: Fmt.shortDid(record.fromDid),
                    badge: mine ? 'You' : null,
                    onTap: () => _copy(context, 'Sender DID', record.fromDid),
                  ),
                  const Divider(height: 1),
                  _Row(
                    label: 'To',
                    value: Fmt.shortDid(record.toDid),
                    badge:
                        myDid != null && record.toDid == myDid ? 'You' : null,
                    onTap: () => _copy(context, 'Recipient DID', record.toDid),
                  ),
                  const Divider(height: 1),
                  _Row(
                    label: 'Date',
                    value: Fmt.dateTime(record.dateTime),
                  ),
                  const Divider(height: 1),
                  _Row(
                    label: 'Authorization',
                    value: record.isWalletSigned
                        ? 'Signed on-device with your key'
                        : 'Authorized by session (node-attested)',
                  ),
                  if (record.id.isNotEmpty) ...[
                    const Divider(height: 1),
                    _Row(
                      label: 'Transaction ID',
                      value: record.id.length > 18
                          ? '${record.id.substring(0, 8)}…'
                              '${record.id.substring(record.id.length - 8)}'
                          : record.id,
                      onTap: () => _copy(context, 'Transaction ID', record.id),
                    ),
                  ],
                  if (record.eventId != null && record.eventId!.isNotEmpty) ...[
                    const Divider(height: 1),
                    _Row(
                      label: 'On-chain event',
                      value: record.eventId!.length > 18
                          ? '${record.eventId!.substring(0, 8)}…'
                              '${record.eventId!.substring(record.eventId!.length - 8)}'
                          : record.eventId!,
                      onTap: () => _copy(context, 'Event ID', record.eventId!),
                    ),
                  ],
                  if (mine) ...[
                    const Divider(height: 1),
                    _Row(
                      label: 'Balance after',
                      value: Fmt.ubc(record.newBalance),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'UBC is soulbound: this transfer spent (burned) the amount from '
              'the sender\'s balance; the recipient DID is recorded for '
              'provenance.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill used for status / finality / signing indicators.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.badge,
    this.onTap,
  });

  final String label;
  final String value;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      trailing:
          onTap == null ? null : const Icon(Icons.copy_outlined, size: 17),
      onTap: onTap,
    );
  }
}
