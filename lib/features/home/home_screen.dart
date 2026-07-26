import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/brand/brand.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/amount.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/states.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../shell/app_shell.dart';

/// The wallet's front page: balance, the two things you actually do with a
/// wallet, and the most recent activity.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final balanceAsync = ref.watch(balanceProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        showBack: false,
        titleWidget: const BrandWordmark(),
        actions: [
          OmniaIconButton(
            icon: Iconsax.scan_barcode_copy,
            tooltip: 'Scan a code',
            onTap: () {
              Haptics.medium();
              context.push('/scan');
            },
          ),
          OmniaIconButton(
            icon: Iconsax.setting_2_copy,
            tooltip: 'Settings',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
      body: OmniaRefresh(
        onRefresh: () async {
          ref.invalidate(balanceProvider);
          ref.invalidate(historyProvider);
          await ref.read(balanceProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.only(bottom: tabBarInset(context) + Space.xxl),
          children: [
            if (balanceAsync.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  0,
                ),
                child:
                    _OfflineBanner(error: friendlyError(balanceAsync.error!)),
              ),
            FadeIn(child: _Balance(balanceAsync: balanceAsync)),
            const FadeIn(
              delay: Duration(milliseconds: 60),
              child: _Actions(),
            ),
            const SizedBox(height: Space.sm),
            Hairline(),
            OmniaSectionHeader(
              title: 'Recent activity',
              action: OmniaTextButton(
                label: 'See all',
                size: FontSizes.sm,
                onTap: () => context.go('/activity'),
              ),
            ),
            const _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance
// ---------------------------------------------------------------------------

/// The balance block.
///
/// Deliberately *not* a card. Bluesky has no elevated card surfaces; the
/// figure earns its prominence from type size and whitespace, and the hairline
/// below it is the only separation it needs.
class _Balance extends StatelessWidget {
  const _Balance({required this.balanceAsync});

  final AsyncValue<Balance> balanceAsync;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.xxl, Space.lg, Space.xl),
      child: balanceAsync.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton.line(width: 64, height: 11),
            SizedBox(height: Space.md),
            Skeleton.line(width: 200, height: 34),
            SizedBox(height: Space.lg),
            Skeleton.line(width: 140, height: 11),
          ],
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance unavailable',
              style: theme.textTheme.labelMedium?.copyWith(color: o.textLow),
            ),
            const SizedBox(height: Space.xs),
            Text('—', style: theme.textTheme.displaySmall),
          ],
        ),
        data: (b) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                fontWeight: Weights.semiBold,
                color: o.textLow,
              ),
            ),
            const SizedBox(height: Space.xs + 2),
            // The one place in the app that uses the largest type step.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: AnimatedCount(
                    value: b.balance,
                    format: Fmt.number,
                    style: theme.textTheme.displayMedium,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  'UBC',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: o.textLow),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            if (b.isRegistered)
              // Flexible on both sides: at large text sizes "Monthly quota"
              // alone can outgrow half the width, and a fixed Row would clip
              // the epoch rather than let the label ellipsise.
              Row(
                children: [
                  Flexible(
                    child: _Stat(
                      label: 'Monthly quota',
                      value: Fmt.number(b.monthlyQuota),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: Space.lg),
                    color: o.borderLow,
                  ),
                  Flexible(
                    child: _Stat(label: 'Epoch', value: '#${b.currentEpoch}'),
                  ),
                ],
              )
            else
              _Notice(
                icon: Iconsax.info_circle_copy,
                text: 'Not registered yet — activity or rewards will '
                    'activate your UBC.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.xs,
            fontWeight: Weights.medium,
            color: o.textLow,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.md,
            fontWeight: Weights.semiBold,
            color: o.text,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: o.textLow),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: FontSizes.sm,
              height: LineHeights.relaxed,
              color: o.textLow,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.error});

  final FriendlyError error;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md + 2,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: o.negative.withValues(alpha: 0.10),
        borderRadius: Radii.rMd,
      ),
      child: Row(
        children: [
          Icon(
            error.isOffline ? Iconsax.wifi_square_copy : Iconsax.danger_copy,
            size: 17,
            color: o.negative,
          ),
          const SizedBox(width: Space.md - 2),
          Expanded(
            child: Text(
              error.message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                height: LineHeights.snug,
                color: o.negative,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        children: [
          Expanded(
            child: OmniaButton(
              label: 'Send',
              icon: Iconsax.arrow_up_3_copy,
              expand: true,
              onPressed: () => context.push('/send'),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: OmniaButton(
              label: 'Receive',
              icon: Iconsax.arrow_down_copy,
              expand: true,
              color: ButtonColor.secondary,
              onPressed: () => context.push('/receive'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity
// ---------------------------------------------------------------------------

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const Column(
        children: [
          TransferSkeleton(),
          TransferSkeleton(),
          TransferSkeleton(),
        ],
      ),
      error: (e, _) => OmniaErrorState(
        message: friendlyError(e).message,
        compact: true,
        onRetry: () => ref.invalidate(historyProvider),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const OmniaEmptyState(
            icon: Iconsax.receipt_2_copy,
            title: 'No activity yet',
            message: 'Transfers on the network will appear here.',
            compact: true,
          );
        }
        final recent = records.reversed.take(6).toList();
        return Column(
          children: [
            for (var i = 0; i < recent.length; i++)
              FadeIn(
                delay: FadeIn.stagger(i),
                child: TransferTile(record: recent[i]),
              ),
          ],
        );
      },
    );
  }
}

/// A loading placeholder shaped exactly like a [TransferTile], so the list
/// doesn't reflow when real data lands.
class TransferSkeleton extends StatelessWidget {
  const TransferSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
      child: Row(
        children: [
          Skeleton.circle(size: 40),
          SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.line(width: 170, height: 13),
                SizedBox(height: Space.sm),
                Skeleton.line(width: 110, height: 11),
              ],
            ),
          ),
          Skeleton.line(width: 44, height: 13),
        ],
      ),
    );
  }
}

/// One transfer in a list.
///
/// Your own sends read loud (a negative-tinted up arrow, a minus sign, "You
/// sent"); everyone else's activity reads quiet and neutral. Tapping opens the
/// full transaction page.
class TransferTile extends ConsumerWidget {
  const TransferTile({super.key, required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final myDid = ref.watch(identityProvider).valueOrNull?.did;
    final mine = myDid != null && record.fromDid == myDid;
    final tint = mine ? o.negative : o.textMedium;

    return Pressable(
      onTap: () => context.push('/tx', extra: record),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconAvatar(
              icon: mine
                  ? Iconsax.arrow_up_3_copy
                  : Iconsax.arrow_swap_horizontal_copy,
              tint: tint,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mine ? 'You sent' : '${Fmt.shortDid(record.fromDid)} sent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: FontSizes.md,
                      fontWeight: mine ? Weights.semiBold : Weights.medium,
                      height: LineHeights.snug,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'To ${Fmt.shortDid(record.toDid)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: o.textLow, height: 1.2),
                        ),
                      ),
                      Text(
                        ' · ${Fmt.relative(record.dateTime)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: o.textLow, height: 1.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mine
                      ? '−${Fmt.number(record.amount)}'
                      : Fmt.number(record.amount),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.md,
                    fontWeight: Weights.bold,
                    color: mine ? o.negative : o.textMedium,
                    fontFeatures: kTabularFigures,
                  ),
                ),
                // At-a-glance provenance / finality; details on the tx screen.
                if (record.isWalletSigned || record.lane0Final == true) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record.lane0Final == true)
                        Icon(Iconsax.flash_1, size: 12, color: o.positive),
                      if (record.isWalletSigned) ...[
                        const SizedBox(width: 3),
                        Icon(Iconsax.shield_tick, size: 12, color: o.accent),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
