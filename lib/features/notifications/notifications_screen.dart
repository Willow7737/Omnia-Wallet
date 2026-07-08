import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../state/notices.dart';

/// The in-app notification feed: transactions, votes, wallet events, news.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the feed clears the badge — after the first frame so the
    // unread indicators are visible for a beat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) ref.read(noticesProvider.notifier).markAllRead();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(noticesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notices.isNotEmpty)
            TextButton(
              onPressed: () {
                Haptics.light();
                ref.read(noticesProvider.notifier).clear();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: notices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sends, votes, and news will show up here.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
                child: _NoticeTile(notice: notices[i]),
              ),
            ),
    );
  }
}

class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.notice});
  final AppNotice notice;

  (IconData, Color) _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final omnia = context.omnia;
    return switch (notice.type) {
      NoticeType.sent => (Icons.arrow_upward, scheme.primary),
      NoticeType.vote => (Icons.how_to_vote_outlined, omnia.success),
      NoticeType.wallet => (
          Icons.account_balance_wallet_outlined,
          scheme.onSurfaceVariant
        ),
      NoticeType.news => (Icons.campaign_outlined, omnia.warning),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, tint) = _style(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: tint.withValues(alpha: 0.14),
        child: Icon(icon, color: tint, size: 22),
      ),
      title: Text(
        notice.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: notice.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          notice.body,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.relative(notice.dateTime),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (!notice.read) ...[
            const SizedBox(height: 6),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
