import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/receive/receive_screen.dart';
import '../features/send/send_screen.dart';
import '../features/settings/settings_screen.dart';
import '../state/providers.dart';

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
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/send', builder: (_, __) => const SendScreen()),
      GoRoute(path: '/receive', builder: (_, __) => const ReceiveScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}
