import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/news.dart';
import '../features/about/about_screen.dart';
import '../features/buy/buy_omnia_screen.dart';
import '../features/pay/merchant_pay_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/governance/governance_screen.dart';
import '../features/history/history_screen.dart';
import '../features/history/transaction_screen.dart';
import '../features/home/home_screen.dart';
import '../features/moderation/safety_screen.dart';
import '../features/network/network_screen.dart';
import '../features/news/news_post_screen.dart';
import '../features/news/news_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/receive/receive_screen.dart';
import '../features/send/scan_did_screen.dart';
import '../features/send/send_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/signin/signin_screen.dart';
import '../features/splash/splash_screen.dart';
import '../state/providers.dart';
import 'motion.dart';

/// A pushed screen: slides in over the tab shell.
Page<void> _push(GoRouterState state, Widget child) => pushPage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      child: child,
    );

/// A tab root: cross-fades, because tabs are peers and horizontal travel would
/// imply a hierarchy that isn't there.
Page<void> _tab(GoRouterState state, Widget child) => fadePage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      child: child,
    );

/// A full-screen takeover that rises from the bottom edge.
Page<void> _modal(GoRouterState state, Widget child) => modalPage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      child: child,
    );

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the app router.
///
/// The signed-in app lives inside a [StatefulShellRoute] with one branch per
/// tab, so each tab keeps its own stack and scroll position. Screens that are
/// *not* tab roots (Send, Receive, a transaction, Settings…) are pushed onto
/// the **root** navigator so they cover the tab bar — which is how Bluesky
/// handles its composer and detail screens.
///
/// Start at a splash while wallet existence resolves asynchronously, so a
/// first-time user routes straight to onboarding instead of flashing an empty
/// Home. [refresh] re-runs the redirect when that state settles.
GoRouter buildRouter(WidgetRef ref, Listenable refresh) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final has = ref.read(hasWalletProvider);
      final loc = state.matchedLocation;

      // Still determining wallet existence → hold on the splash.
      if (!has.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }

      final hasWallet = has.value ?? false;
      if (!hasWallet) {
        // Sign-in (Mode B) is part of the no-wallet funnel too.
        return (loc == '/onboarding' || loc == '/signin')
            ? null
            : '/onboarding';
      }
      // An identity exists — never sit on splash/onboarding/sign-in.
      if (loc == '/splash' || loc == '/onboarding' || loc == '/signin') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, s) => _tab(s, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, s) => _tab(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/signin',
        pageBuilder: (_, s) => _push(s, const SignInScreen()),
      ),

      // ---- the tab shell ----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, s) => _tab(s, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                pageBuilder: (_, s) => _tab(s, const HistoryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/news',
                pageBuilder: (_, s) => _tab(s, const NewsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (_, s) => _tab(s, const NotificationsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, s) => _tab(s, const ProfileScreen()),
              ),
            ],
          ),
        ],
      ),

      // ---- pushed over the shell (root navigator) ----
      GoRoute(
        path: '/buy-omnia',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const BuyOmniaScreen()),
      ),
      GoRoute(
        path: '/pay-merchant',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const MerchantPayScreen()),
      ),
      GoRoute(
        path: '/send',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const SendScreen()),
      ),
      GoRoute(
        path: '/receive',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const ReceiveScreen()),
      ),
      GoRoute(
        path: '/scan',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _modal(s, const ScanDidScreen()),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/contacts',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const ContactsScreen()),
      ),
      GoRoute(
        path: '/governance',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const GovernanceScreen()),
      ),
      GoRoute(
        path: '/network',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const NetworkScreen()),
      ),
      GoRoute(
        path: '/safety',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const SafetyScreen()),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _push(s, const AboutScreen()),
      ),
      GoRoute(
        path: '/tx',
        parentNavigatorKey: _rootKey,
        // Tiles pass the record along; a bare deep link goes to Activity.
        redirect: (_, s) => s.extra is TransferRecord ? null : '/activity',
        pageBuilder: (_, s) =>
            _push(s, TransactionScreen(record: s.extra! as TransferRecord)),
      ),
      GoRoute(
        path: '/post',
        parentNavigatorKey: _rootKey,
        // The feed passes the post along; a bare deep link falls back to the
        // feed rather than fetching a single post.
        redirect: (_, s) => s.extra is NewsPost ? null : '/news',
        pageBuilder: (_, s) =>
            _push(s, NewsPostScreen(post: s.extra! as NewsPost)),
      ),
    ],
  );
}
