import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_count.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models.dart';
import '../../state/news.dart';
import '../../state/notices.dart';
import '../../state/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final theme = Theme.of(context);

    // Fetch news in the background so a fresh post files a notification
    // even before the user opens the News tab.
    ref.watch(newsPostsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const BrandWordmark(markSize: 28, fontSize: 28),
        toolbarHeight: 68,
        // One uncluttered entry point: everything lives in the avatar menu.
        actions: const [_AvatarMenu()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          Haptics.light();
          ref.invalidate(balanceProvider);
          ref.invalidate(historyProvider);
          await ref.read(balanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (balanceAsync.hasError) ...[
              _OfflineBanner(error: friendlyError(balanceAsync.error!)),
              const SizedBox(height: 16),
            ],
            FadeSlideIn(child: _BalanceCard(balanceAsync: balanceAsync)),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: Motion.micro,
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_upward,
                      label: 'Send',
                      color: context.omnia.negative,
                      onTap: () => context.push('/send'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_downward,
                      label: 'Receive',
                      color: context.omnia.positive,
                      onTap: () => context.push('/receive'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent activity', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    Haptics.light();
                    context.push('/history');
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

/// The avatar in the top bar: shows an unread dot and opens a dropdown with
/// Profile, Notifications, News, Governance, and Settings.
class _AvatarMenu extends ConsumerWidget {
  const _AvatarMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesProvider);
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onOpened: Haptics.light,
      onSelected: (route) {
        Haptics.selection();
        context.push(route);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: '/profile',
          child: _MenuRow(icon: Icons.person_outline, label: 'Profile'),
        ),
        PopupMenuItem(
          value: '/notifications',
          child: _MenuRow(
            icon: Icons.notifications_none,
            label: 'Notifications',
            badgeCount: unread,
          ),
        ),
        const PopupMenuItem(
          value: '/news',
          child: _MenuRow(icon: Icons.newspaper_outlined, label: 'News'),
        ),
        const PopupMenuItem(
          value: '/governance',
          child:
              _MenuRow(icon: Icons.how_to_vote_outlined, label: 'Governance'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '/settings',
          child: _MenuRow(icon: Icons.settings_outlined, label: 'Settings'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 16, left: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const UserAvatar(size: 36),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.badgeCount});

  final IconData icon;
  final String label;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        if ((badgeCount ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.error,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeCount! > 9 ? '9+' : '$badgeCount',
              style: TextStyle(
                color: scheme.onError,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            error.isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
            color: scheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceAsync});
  final AsyncValue<Balance> balanceAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: balanceAsync.when(
          loading: () => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 80, height: 14),
              SizedBox(height: 14),
              ShimmerBox(width: 200, height: 40, radius: 10),
              SizedBox(height: 18),
              ShimmerBox(width: 150, height: 14),
            ],
          ),
          error: (e, _) => SizedBox(
            height: 96,
            child: Center(
              child: Text(
                friendlyError(e).message,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              AnimatedCount(
                value: b.balance,
                format: Fmt.ubc,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              if (b.isRegistered)
                Wrap(
                  spacing: 16,
                  children: [
                    _Meta(
                      label: 'Monthly quota',
                      value: Fmt.number(b.monthlyQuota),
                    ),
                    _Meta(label: 'Epoch', value: '#${b.currentEpoch}'),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Not registered yet — activity or rewards will activate your UBC.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Semantic tint: send reads warm/red, receive reads green.
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () {
        Haptics.light();
        onTap();
      },
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: color.withValues(alpha: 0.13),
        foregroundColor: color,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _ActivitySkeleton(),
            SizedBox(height: 12),
            _ActivitySkeleton(),
            SizedBox(height: 12),
            _ActivitySkeleton(),
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(friendlyError(e).message),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No transactions yet')),
          );
        }
        final recent = records.reversed.take(5).toList();
        return Column(
          children: [
            for (var i = 0; i < recent.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: TransferTile(record: recent[i]),
              ),
          ],
        );
      },
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerBox(width: 40, height: 40, radius: 20),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 140, height: 14),
            SizedBox(height: 8),
            ShimmerBox(width: 90, height: 12),
          ],
        ),
      ],
    );
  }
}

/// One transfer in a list. Your own sends read loud (red, minus, "You
/// sent"); other users' activity reads quiet and neutral. Tapping opens the
/// full transaction page.
class TransferTile extends ConsumerWidget {
  const TransferTile({super.key, required this.record});
  final TransferRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final omnia = context.omnia;
    final myDid = ref.watch(identityProvider).valueOrNull?.did;
    final mine = myDid != null && record.fromDid == myDid;

    final tint = mine ? omnia.negative : scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        Haptics.light();
        context.push('/tx', extra: record);
      },
      leading: CircleAvatar(
        backgroundColor: tint.withValues(alpha: 0.12),
        child: Icon(
          mine ? Icons.arrow_upward : Icons.swap_horiz,
          color: tint,
          size: 22,
        ),
      ),
      title: Text(
        mine
            ? 'You sent ${Fmt.ubc(record.amount)}'
            : '${Fmt.shortDid(record.fromDid)} sent '
                '${Fmt.ubc(record.amount)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'To ${Fmt.shortDid(record.toDid)}\n${Fmt.dateTime(record.dateTime)}',
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mine ? '−${record.amount}' : '${record.amount}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: mine ? omnia.negative : scheme.onSurfaceVariant,
            ),
          ),
          // At-a-glance provenance/finality cues (details on the tx screen).
          if (record.isWalletSigned || record.lane0Final == true) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (record.lane0Final == true)
                  Icon(Icons.bolt, size: 13, color: omnia.success),
                if (record.isWalletSigned)
                  Icon(Icons.verified_user_outlined,
                      size: 12, color: scheme.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
