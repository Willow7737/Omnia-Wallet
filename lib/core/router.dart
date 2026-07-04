import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/receive/receive_screen.dart';
import '../features/send/send_screen.dart';
import '../features/settings/settings_screen.dart';
import '../state/providers.dart';
import 'motion.dart';

/// Wrap a screen in the shared fade-through transition.
Page<void> _page(GoRouterState state, Widget child) => fadeThroughPage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      child: child,
    );

/// Builds the app router. Redirects to onboarding until a wallet exists.
GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final hasWallet = ref.read(hasWalletProvider).valueOrNull;
      if (hasWallet == null) return null; // still loading
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!hasWallet && !onOnboarding) return '/onboarding';
      if (hasWallet && onOnboarding) return '/';
      return null;
    },
    routes: [
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
    ],
  );
}
