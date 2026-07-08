import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand.dart';
import '../../core/brand/identicon.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_count.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/shimmer.dart';
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

    final identity = ref.watch(identityProvider).valueOrNull;
    // Fetch news in the background so a fresh post files a notification
    // even before the user opens the News tab.
    ref.watch(newsPostsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const BrandWordmark(markSize: 28, fontSize: 28),
        toolbarHeight: 68,
        actions: [
          IconButton(
            tooltip: 'News',
            icon: const Icon(Icons.newspaper_outlined),
            onPressed: () {
              Haptics.light();
              context.push('/news');
            },
          ),
          const _NotificationsBell(),
          IconButton(
            tooltip: 'Governance',
            icon: const Icon(Icons.how_to_vote_outlined),
            onPressed: () {
              Haptics.light();
              context.push('/governance');
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Haptics.light();
              context.push('/settings');
            },
          ),
          if (identity != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.push('/profile');
                },
                child: ClipOval(child: Identicon(seed: identity.did, size: 34)),
              ),
            ),
        ],
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
                      onTap: () => context.push('/send'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.qr_code,
                      label: 'Receive',
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

/// Bell icon with an unread-count badge.
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        Haptics.light();
        context.push('/notifications');
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
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

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.record});
  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final negative = context.omnia.negative;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.arrow_upward)),
      title: Text('Sent ${Fmt.ubc(record.amount)}'),
      subtitle: Text(
        'To ${Fmt.shortDid(record.toDid)}\n${Fmt.dateTime(record.dateTime)}',
      ),
      isThreeLine: true,
      trailing: Text(
        '−${record.amount}',
        style: TextStyle(fontWeight: FontWeight.w700, color: negative),
      ),
    );
  }
}
