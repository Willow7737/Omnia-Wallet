import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/supabase_gateway.dart';
import 'features/lock/app_lock_gate.dart';
import 'state/providers.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: the header and tab bar are translucent and blur what passes
  // beneath them, which only works if the system bars aren't reserving space.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Mode B (Supabase sign-in). Failure only disables sign-in — never blocks
  // launch, since Mode A is fully local.
  await SupabaseFlutterGateway.init();
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
    // Warm the haptics preference so the very first tap already respects it.
    ref.read(hapticsEnabledProvider);

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
    // The app is explicitly themed rather than following the platform: ALF
    // ships three themes (Light / Dim / Dark), and the extra "dim" step has no
    // equivalent in Flutter's two-valued ThemeMode.
    final theme = OmniaTheme.of(ref.watch(themeProvider));

    return MaterialApp.router(
      title: 'Omnia Wallet',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: _router,
      builder: (context, child) {
        // Pin text scaling to a sane band. The balance figure and the tab bar
        // both break down past ~1.3x, and the system setting can reach 2x.
        final scaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: AppLockGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Exposed for tests/documentation of the configured default endpoint.
String get configuredDefaultNodeUrl => AppConfig.defaultNodeUrl;
