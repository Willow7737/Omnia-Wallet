import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Everything about one transfer: direction, amount, parties, timing, ids.
class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key, required this.record});

  final TransferRecord record;

  void _copy(BuildContext context, String label, String value) {
    Haptics.selection();
    Clipboard.setData(ClipboardData(text: value));
    showOmniaToast(context, message: '$label copied', icon: Iconsax.copy_success_copy);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final myDid = ref.watch(identityProvider).valueOrNull?.did;
    final mine = myDid != null && record.fromDid == myDid;
    final tint = mine ? o.negative : o.textMedium;

    final status = record.status.toLowerCase();
    final ok = status == 'completed' || status == 'success';

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Transaction',
        actions: [
          if (record.id.isNotEmpty)
            OmniaIconButton(
              icon: Iconsax.copy_copy,
              tooltip: 'Copy transaction ID',
              onTap: () => _copy(context, 'Transaction ID', record.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x4l),
        children: [
          // ---- hero ----
          FadeIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.xl,
                Space.xl,
                Space.xxl,
              ),
              child: Column(
                children: [
                  IconAvatar(
                    icon: mine
                        ? Iconsax.arrow_up_3_copy
                        : Iconsax.arrow_swap_horizontal_copy,
                    tint: tint,
                    size: 64,
                    iconSize: 28,
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    mine
                        ? '−${Fmt.ubc(record.amount)}'
                        : Fmt.ubc(record.amount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: mine ? o.negative : o.text,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    Fmt.dateTime(record.dateTime),
                    style: theme.textTheme.bodySmall?.copyWith(color: o.textLow),
                  ),
                  const SizedBox(height: Space.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      OmniaPill(
                        label: record.status.isEmpty
                            ? 'recorded'
                            : record.status,
                        icon: ok ? Iconsax.tick_circle : Iconsax.clock_copy,
                        color: ok ? o.positive : o.warning,
                      ),
                      // Lane 0 fast-path finality — only when the node
                      // actually tracks it.
                      if (record.lane0Final != null)
                        OmniaPill(
                          label: record.lane0Final!
                              ? 'Final · Lane 0'
                              : 'Awaiting finality',
                          icon: record.lane0Final!
                              ? Iconsax.flash_1
                              : Iconsax.timer_copy,
                          color: record.lane0Final! ? o.positive : o.textMedium,
                        ),
                      // Authorized by the on-device key, not just the session.
                      if (record.isWalletSigned)
                        OmniaPill(
                          label: 'Signed on-device',
                          icon: Iconsax.shield_tick,
                          color: o.accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ---- parties ----
          const Hairline(),
          _Party(
            role: 'From',
            did: record.fromDid,
            isYou: mine,
            onCopy: () => _copy(context, 'Sender DID', record.fromDid),
          ),
          const Hairline(indent: Space.lg),
          _Party(
            role: 'To',
            did: record.toDid,
            isYou: myDid != null && record.toDid == myDid,
            onCopy: () => _copy(context, 'Recipient DID', record.toDid),
          ),
          const Hairline(),

          // ---- details ----
          const OmniaSectionLabel('Details'),
          _Detail(
            label: 'Authorization',
            value: record.isWalletSigned
                ? 'Signed on-device with your key'
                : 'Authorized by session (node-attested)',
          ),
          const Hairline(indent: Space.lg),
          _Detail(label: 'Date', value: Fmt.dateTime(record.dateTime)),
          if (record.id.isNotEmpty) ...[
            const Hairline(indent: Space.lg),
            _Detail(
              label: 'Transaction ID',
              value: Fmt.shortId(record.id),
              mono: true,
              onCopy: () => _copy(context, 'Transaction ID', record.id),
            ),
          ],
          if (record.eventId != null && record.eventId!.isNotEmpty) ...[
            const Hairline(indent: Space.lg),
            _Detail(
              label: 'On-chain event',
              value: Fmt.shortId(record.eventId!),
              mono: true,
              onCopy: () => _copy(context, 'Event ID', record.eventId!),
            ),
          ],
          if (mine) ...[
            const Hairline(indent: Space.lg),
            _Detail(
              label: 'Balance after',
              value: Fmt.ubc(record.newBalance),
            ),
          ],
          const Hairline(),

          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Iconsax.info_circle_copy, size: 16, color: o.textLow),
                const SizedBox(width: Space.md - 2),
                Expanded(
                  child: Text(
                    'UBC is soulbound: this transfer spent (burned) the amount '
                    'from the sender\'s balance. The recipient DID is recorded '
                    'for provenance.',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: o.textLow),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A counterparty row: identicon, role, DID, and a "You" marker when it's the
/// signed-in wallet.
class _Party extends StatelessWidget {
  const _Party({
    required this.role,
    required this.did,
    required this.isYou,
    required this.onCopy,
  });

  final String role;
  final String did;
  final bool isYou;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Pressable(
      onTap: onCopy,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          children: [
            DidAvatar(did: did, size: 40),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        role,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: o.textLow),
                      ),
                      if (isYou) ...[
                        const SizedBox(width: Space.sm),
                        OmniaPill(label: 'You', color: o.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.shortDid(did),
                    style: monoStyle(fontSize: FontSizes.sm, color: o.text),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.copy_copy, size: 17, color: o.textLow),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.mono = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Pressable(
      onTap: onCopy,
      haptic: onCopy != null,
      feel: onCopy == null ? PressFeel.none : PressFeel.normal,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
            ),
            const SizedBox(width: Space.xl),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: mono
                    ? monoStyle(fontSize: FontSizes.sm, color: o.text)
                    : theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: Weights.medium,
                        fontFeatures: kTabularFigures,
                      ),
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: Space.sm),
              Icon(Iconsax.copy_copy, size: 15, color: o.textLow),
            ],
          ],
        ),
      ),
    );
  }
}
