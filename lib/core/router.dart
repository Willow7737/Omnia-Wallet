import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/contacts/contacts_screen.dart';
import '../features/governance/governance_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/receive/receive_screen.dart';
import '../features/send/send_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../state/providers.dart';
import 'motion.dart';

/// Wrap a screen in the shared fade-through transition.
Page<void> _page(GoRouterState state, Widget child) => fadeThroughPage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      child: child,
    );

/// Builds the app router.
///
/// Start at a splash while we asynchronously determine whether a wallet
/// exists, so a first-time user is routed straight to onboarding instead of
/// flashing the (empty) Home screen. [refresh] re-runs the redirect when the
/// wallet-existence state resolves or changes.
GoRouter buildRouter(WidgetRef ref, Listenable refresh) {
  return GoRouter(
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
        return loc == '/onboarding' ? null : '/onboarding';
      }
      // A wallet exists — never sit on splash/onboarding.
      if (loc == '/splash' || loc == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, s) => _page(s, const SplashScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (_, s) => _page(s, const HomeScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, s) => _page(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/send',
        pageBuilder: (_, s) => _page(s, const SendScreen()),
      ),
      GoRoute(
        path: '/receive',
        pageBuilder: (_, s) => _page(s, const ReceiveScreen()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (_, s) => _page(s, const HistoryScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, s) => _page(s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/contacts',
        pageBuilder: (_, s) => _page(s, const ContactsScreen()),
      ),
      GoRoute(
        path: '/governance',
        pageBuilder: (_, s) => _page(s, const GovernanceScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, s) => _page(s, const ProfileScreen()),
      ),
    ],
  );
}
