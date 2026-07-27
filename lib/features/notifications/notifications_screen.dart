import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../state/news.dart';
import '../../state/notices.dart';
import '../../state/providers.dart';
import '../shell/app_shell.dart';

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
    // Opening the feed clears the badge — but only after a beat, so the unread
    // markers are actually visible before they fade.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) ref.read(noticesProvider.notifier).markAllRead();
      });
    });
  }

  Future<void> _clear() async {
    final confirmed = await showOmniaConfirm(
      context,
      icon: Iconsax.trash_copy,
      title: 'Clear notifications?',
      message: 'This removes every notification from this device.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(noticesProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final notices = ref.watch(noticesProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Notifications',
        showBack: false,
        actions: [
          if (notices.isNotEmpty)
            OmniaIconButton(
              icon: Iconsax.trash_copy,
              tooltip: 'Clear all',
              onTap: _clear,
            ),
        ],
      ),
      body: notices.isEmpty
          ? OmniaEmptyState(
              icon: Iconsax.notification_copy,
              title: 'Nothing yet',
              message: 'Sends, votes and news will show up here.',
              bottomInset: tabBarInset(context),
            )
          : ListView.separated(
              padding: EdgeInsets.only(bottom: tabBarInset(context) + Space.xl),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const Hairline(indent: 68),
              itemBuilder: (_, i) => FadeIn(
                delay: FadeIn.stagger(i),
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
    final o = context.omnia;
    return switch (notice.type) {
      NoticeType.sent => (Iconsax.arrow_up_3_copy, o.negative),
      NoticeType.vote => (Iconsax.chart_2_copy, o.positive),
      NoticeType.wallet => (Iconsax.wallet_copy, o.textMedium),
      NoticeType.news => (Iconsax.global_copy, o.accent),
    };
  }

  /// Open what the notice is *about*, not merely the list it lives in.
  ///
  /// A "sent 39 UBC" notification that drops you at the top of the whole
  /// activity log has told you nothing you did not already know. The subject
  /// is looked up in the data the app already holds; if it has aged out — the
  /// transfer is past the end of the log, the post has been deleted — the
  /// list is the honest fallback rather than an error.
  void _open(BuildContext context, WidgetRef ref) {
    // Opening a notification is also the moment it stops being news, so clear
    // the badge before navigating rather than waiting for the screen's own
    // mark-all timer.
    ref.read(noticesProvider.notifier).markAllRead();

    final subjectId = notice.subjectId;
    if (subjectId != null) {
      switch (notice.type) {
        case NoticeType.sent:
          final record = ref
              .read(historyProvider)
              .valueOrNull
              ?.where((r) => r.id == subjectId)
              .firstOrNull;
          if (record != null) {
            context.push('/tx', extra: record);
            return;
          }
        case NoticeType.news:
          final post = ref
              .read(newsPostsProvider)
              .valueOrNull
              ?.where((p) => p.id == subjectId)
              .firstOrNull;
          if (post != null) {
            context.push('/post', extra: post);
            return;
          }
        case NoticeType.vote:
        case NoticeType.wallet:
          break;
      }
    }

    final destination = notice.destination;
    // Tab roots switch tabs; everything else stacks on top.
    const tabs = {'/', '/activity', '/news', '/notifications', '/profile'};
    if (tabs.contains(destination)) {
      context.go(destination);
    } else {
      context.push(destination);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final (icon, tint) = _style(context);
    final unread = !notice.read;

    return Pressable(
      onTap: () => _open(context, ref),
      child: Container(
        // Unread rows carry a faint accent wash — the same cue Bluesky uses on
        // an unread notification, and quieter than a coloured dot on every row.
        color: unread ? o.accent.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconAvatar(icon: icon, tint: tint),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: FontSizes.md,
                            fontWeight: unread ? Weights.bold : Weights.medium,
                            height: LineHeights.snug,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        Fmt.relative(notice.dateTime),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: o.textLow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: o.textMedium,
                      height: LineHeights.snug,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
