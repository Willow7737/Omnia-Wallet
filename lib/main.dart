import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/supabase_gateway.dart';
import 'features/lock/app_lock_gate.dart';
import 'state/profile.dart';
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

  /// Pulls the account's name and picture down whenever a session appears.
  StreamSubscription<void>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Warm the haptics preference so the very first tap already respects it.
    ref.read(hapticsEnabledProvider);

    // The profile lives on the account, so a launch that already holds a
    // session reconciles immediately, and a sign-in that arrives later
    // reconciles then. Without the second, a freshly re-added wallet keeps
    // showing the identicon until the next cold start.
    _profileSub = ref
        .read(supabaseGatewayProvider)
        .signedIn
        .listen((_) => ref.read(profileSyncProvider).sync());

    // Load a persisted node URL override (if any) after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(ref.read(profileSyncProvider).sync());
      final saved = await ref.read(secureStoreProvider).readNodeUrl();
      if (saved != null && saved.isNotEmpty && mounted) {
        ref.read(nodeUrlProvider.notifier).state = saved;
      }
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themes = OmniaTheme.modeFor(ref.watch(themeProvider));

    return MaterialApp.router(
      title: 'Omnia Wallet',
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: themes.mode,
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
