import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/lock/app_lock_gate.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OmniaWalletApp()));
}

class OmniaWalletApp extends ConsumerStatefulWidget {
  const OmniaWalletApp({super.key});

  @override
  ConsumerState<OmniaWalletApp> createState() => _OmniaWalletAppState();
}

class _OmniaWalletAppState extends ConsumerState<OmniaWalletApp> {
  // Bridges Riverpod's async wallet-existence state into a Listenable the
  // router can refresh on. Built once so the router isn't recreated per build.
  final ValueNotifier<int> _routerRefresh = ValueNotifier<int>(0);
  late final GoRouter _router = _buildOnce();

  GoRouter _buildOnce() {
    // Re-run the router's redirect whenever wallet existence resolves/changes.
    ref.listenManual(hasWalletProvider, (_, __) => _routerRefresh.value++);
    return buildRouter(ref, _routerRefresh);
  }

  @override
  void initState() {
    super.initState();
    // Load a persisted node URL override (if any) after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await ref.read(secureStoreProvider).readNodeUrl();
      if (saved != null && saved.isNotEmpty && mounted) {
        ref.read(nodeUrlProvider.notifier).state = saved;
      }
    });
  }

  @override
  void dispose() {
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Omnia Wallet',
      debugShowCheckedModeBanner: false,
      theme: OmniaTheme.light(),
      darkTheme: OmniaTheme.dark(),
      routerConfig: _router,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Exposed for tests/documentation of the configured default endpoint.
String get configuredDefaultNodeUrl => AppConfig.defaultNodeUrl;
