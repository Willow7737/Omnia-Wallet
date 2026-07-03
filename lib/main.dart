import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
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
  Widget build(BuildContext context) {
    final router = buildRouter(ref);
    return MaterialApp.router(
      title: 'Omnia Wallet',
      debugShowCheckedModeBanner: false,
      theme: OmniaTheme.light(),
      darkTheme: OmniaTheme.dark(),
      routerConfig: router,
    );
  }
}

/// Exposed for tests/documentation of the configured default endpoint.
String get configuredDefaultNodeUrl => AppConfig.defaultNodeUrl;
