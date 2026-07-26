import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/theme.dart';
import '../../core/ui/tab_bar.dart';
import '../../state/news.dart';
import '../../state/notices.dart';

/// The persistent tab shell.
///
/// Bluesky is a five-tab bottom shell: the bar is always on screen, each tab
/// keeps its own navigation stack and scroll position, and pushed detail
/// screens cover the whole shell rather than sliding in beneath the bar.
/// `StatefulShellRoute` is go_router's equivalent, and
/// [StatefulNavigationShell.goBranch] with `initialLocation: index == current`
/// is what gives tabs the "tap again to pop to root" behaviour people expect.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesProvider);
    final hasFreshNews = ref.watch(hasUnreadNewsProvider);

    // Keep the news feed warm in the background so a new post can raise its
    // dot without the user having opened the tab.
    ref.watch(newsPostsProvider);

    return Scaffold(
      backgroundColor: context.omnia.bg,
      // The bar is translucent and blurs what passes under it, so the body
      // has to extend behind it.
      extendBody: true,
      body: shell,
      bottomNavigationBar: OmniaTabBar(
        index: shell.currentIndex,
        onSelect: (index) => shell.goBranch(
          index,
          // Re-tapping the current tab resets it to its root.
          initialLocation: index == shell.currentIndex,
        ),
        tabs: [
          const OmniaTab(
            icon: Iconsax.home_2_copy,
            activeIcon: Iconsax.home_2,
            label: 'Home',
          ),
          const OmniaTab(
            icon: Iconsax.arrange_square_copy,
            activeIcon: Iconsax.arrange_square,
            label: 'Activity',
          ),
          OmniaTab(
            icon: Iconsax.global_copy,
            activeIcon: Iconsax.global,
            label: 'News',
            showDot: hasFreshNews,
          ),
          OmniaTab(
            icon: Iconsax.notification_copy,
            activeIcon: Iconsax.notification,
            label: 'Notifications',
            badgeCount: unread,
          ),
          const OmniaTab(
            icon: Iconsax.user_copy,
            activeIcon: Iconsax.user,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Bottom padding that clears the translucent tab bar plus the home
/// indicator. Every scrolling tab body needs this as its final inset,
/// otherwise the last row sits permanently under the bar.
double tabBarInset(BuildContext context) =>
    OmniaTabBar.barHeight + MediaQuery.viewPaddingOf(context).bottom;
