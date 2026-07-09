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
                const SizedBox(height: 6),
                // Status chip.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: (ok ? omnia.success : omnia.warning)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.status.isEmpty ? 'recorded' : record.status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ok ? omnia.success : omnia.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
