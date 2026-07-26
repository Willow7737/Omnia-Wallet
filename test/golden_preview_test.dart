@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/crypto/key_manager.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/governance.dart';
import 'package:omnia_wallet/data/models.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/contacts/contacts_screen.dart';
import 'package:omnia_wallet/features/governance/governance_screen.dart';
import 'package:omnia_wallet/features/history/history_screen.dart';
import 'package:omnia_wallet/features/history/transaction_screen.dart';
import 'package:omnia_wallet/features/home/home_screen.dart';
import 'package:omnia_wallet/features/moderation/safety_screen.dart';
import 'package:omnia_wallet/features/network/network_screen.dart';
import 'package:omnia_wallet/features/news/news_screen.dart';
import 'package:omnia_wallet/features/notifications/notifications_screen.dart';
import 'package:omnia_wallet/features/profile/profile_screen.dart';
import 'package:omnia_wallet/features/receive/receive_screen.dart';
import 'package:omnia_wallet/features/send/send_screen.dart';
import 'package:omnia_wallet/features/settings/settings_screen.dart';
import 'package:omnia_wallet/state/governance.dart';
import 'package:omnia_wallet/state/news.dart';
import 'package:omnia_wallet/state/providers.dart';

/// Renders each screen to a PNG under `build/preview/` so the redesign can be
/// eyeballed without a device.
///
/// Tagged `preview` and excluded from the default run (see
/// `dart_test.yaml`) — it writes files and is a development aid, not an
/// assertion. Run it with:
///
/// ```
/// flutter test --tags preview test/golden_preview_test.dart
/// ```
/// Load the real typefaces into the test renderer.
///
/// `flutter test` ships a placeholder font that draws every glyph as a filled
/// box, so without this the previews are unreadable rectangles. Inter comes
/// from the app's own assets; the icon font is pulled out of the
/// `iconsax_flutter` package in `.dart_tool/package_config.json`.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(file.readAsBytesSync().buffer.asByteData()),
      );
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);

  // The icon font lives in the pub cache; resolve it through package_config
  // rather than hard-coding a version-stamped path.
  final config = File('.dart_tool/package_config.json');
  if (config.existsSync()) {
    final match = RegExp(r'"name"\s*:\s*"iconsax_flutter"\s*,\s*'
            r'"rootUri"\s*:\s*"([^"]+)"')
        .firstMatch(config.readAsStringSync());
    if (match != null) {
      final root = Uri.parse(match.group(1)!);
      final base = root.isAbsolute
          ? root.toFilePath()
          : Directory('.dart_tool').uri.resolveUri(root).toFilePath();
      // An IconData carrying `fontPackage` resolves to the family
      // `packages/<package>/<family>`, so that is the key FontLoader must
      // register under — plain 'FlutterIconsax' never matches and every
      // icon falls back to the placeholder box glyph.
      await load(
        'packages/iconsax_flutter/FlutterIconsax',
        ['$base/fonts/FlutterIconsax.ttf'],
      );
    }
  }
}

void main() {
  setUpAll(_loadFonts);

  const did = 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237';
  const otherDid = 'did:omnia:71a9c0e0f2b41d8a';

  final identity = WalletIdentity(did: did, publicKeyHex: 'ab' * 32);

  final balance = Balance(
    did: did,
    balance: 800,
    monthlyQuota: 1000,
    currentEpoch: 0,
    isRegistered: true,
  );

  TransferRecord tx({
    required String from,
    required String to,
    required int amount,
    required Duration ago,
    bool signed = false,
    bool? finalized,
  }) =>
      TransferRecord(
        id: 'a7f3c9e2b41d8a5f6c0e9b3d2a1f4e7c',
        fromDid: from,
        toDid: to,
        amount: amount,
        newBalance: 761,
        status: 'completed',
        timestamp: DateTime.now().subtract(ago).millisecondsSinceEpoch,
        lane0Final: finalized,
        provenance: signed ? 'wallet_signed' : 'node_attested',
      );

  List<TransferRecord> history() => [
        tx(from: did, to: otherDid, amount: 39, ago: const Duration(hours: 2),
            signed: true, finalized: true),
        tx(from: otherDid, to: did, amount: 97, ago: const Duration(hours: 6)),
        tx(from: did, to: otherDid, amount: 32, ago: const Duration(days: 1),
            signed: true),
        tx(from: otherDid, to: did, amount: 46, ago: const Duration(days: 2)),
      ].reversed.toList();

  final nodeInfo = NodeInfo(
    version: '0.4.1',
    protocolVersion: '1',
    uptimeSeconds: 90061,
    peers: 12,
    finalizedHeight: 148230,
    shardCount: 4,
  );

  final posts = [
    NewsPost(
      id: 'post-1',
      title: 'Lane 0 finality is live on testnet',
      body: 'Transfers now settle on the fast path in under a second. The '
          'wallet shows a bolt on any transfer that has reached Lane 0, and '
          'the transaction screen explains what that means.',
      tags: const ['protocol', 'release'],
      author: 'omnia',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      replyCount: 3,
    ),
    NewsPost(
      id: 'post-2',
      title: 'Governance: raising the monthly quota',
      body: 'A proposal to lift the monthly UBC quota from 1,000 to 1,200 is '
          'open for voting until epoch 4.',
      tags: const ['governance'],
      author: 'omnia',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      replyCount: 11,
    ),
  ];

  final proposals = [
    Proposal(
      id: 'prop-1',
      description: 'Raise the monthly quota to 1,200 UBC',
      createdAtEpoch: 0,
      expiresAtEpoch: 4,
      votesFor: 128,
      votesAgainst: 41,
      votesAbstain: 12,
      executionTime: null,
      status: 'voting',
      totalParticipation: 181,
    ),
    Proposal(
      id: 'prop-2',
      description: 'Shorten the epoch to seven days',
      createdAtEpoch: 0,
      expiresAtEpoch: 2,
      votesFor: 204,
      votesAgainst: 18,
      votesAbstain: 3,
      executionTime: null,
      status: 'passed',
      totalParticipation: 225,
    ),
  ];

  List<Override> overrides() => [
        secureStoreProvider.overrideWithValue(_PreviewStore()),
        identityProvider.overrideWith((ref) async => identity),
        hasWalletProvider.overrideWith((ref) async => true),
        balanceProvider.overrideWith((ref) async => balance),
        historyProvider.overrideWith((ref) async => history()),
        nodeInfoProvider.overrideWith((ref) async => nodeInfo),
        displayNameProvider.overrideWith((ref) async => 'Ama'),
        newsPostsProvider.overrideWith((ref) async => posts),
        proposalsProvider.overrideWith((ref) async => proposals),
      ];

  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'activity': const HistoryScreen(),
    'news': const NewsScreen(),
    'notifications': const NotificationsScreen(),
    'profile': const ProfileScreen(),
    'send': const SendScreen(),
    'receive': const ReceiveScreen(),
    'settings': const SettingsScreen(),
    'contacts': const ContactsScreen(),
    'governance': const GovernanceScreen(),
    'network': const NetworkScreen(),
    'safety': const SafetyScreen(),
    'transaction': TransactionScreen(
      record: tx(
        from: did,
        to: otherDid,
        amount: 39,
        ago: const Duration(hours: 2),
        signed: true,
        finalized: true,
      ),
    ),
  };

  final themes = <String, ThemeData>{
    'light': OmniaTheme.light(),
    'dim': OmniaTheme.dim(),
  };

  for (final theme in themes.entries) {
    for (final screen in screens.entries) {
      testWidgets('preview ${screen.key} (${theme.key})', (tester) async {
        // A 390x844 logical viewport — an iPhone 15 / Pixel 8 class screen.
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.value,
              home: RepaintBoundary(
                key: const ValueKey('shot'),
                child: screen.value,
              ),
            ),
          ),
        );
        // Pump repeatedly rather than once: a `FadeIn` with a delay starts
        // its controller from inside a timer, and a controller started during
        // frame N only advances on frame N+1. One long pump leaves every
        // staggered element stuck at opacity zero.
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shot')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

        final dir = Directory('build/preview')..createSync(recursive: true);
        File('${dir.path}/${theme.key}_${screen.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  }
}

class _PreviewStore extends SecureStore {
  @override
  Future<String?> readContacts() async =>
      '[{"label":"Ama","did":"did:omnia:71a9c0e0f2b41d8a"},'
      '{"label":"Kofi","did":"did:omnia:933eaf87c1204b6d"},'
      '{"label":"Node ops","did":"did:omnia:5b2c8de147a09f31"}]';

  @override
  Future<String?> readNotices() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '['
        '{"id":"1","type":"sent","title":"Sent 39 UBC",'
        '"body":"To did:omnia:71a9…1d8a · new balance 761 UBC · signed on-device",'
        '"timestamp":${now - 7200000},"read":false},'
        '{"id":"2","type":"news","title":"News from the Omnia team",'
        '"body":"Lane 0 finality is live on testnet",'
        '"timestamp":${now - 18000000},"read":false},'
        '{"id":"3","type":"vote","title":"Vote recorded: for",'
        '"body":"On \\"prop-1\\" · weight 12","timestamp":${now - 86400000},'
        '"read":true},'
        '{"id":"4","type":"wallet","title":"Wallet created",'
        '"body":"Recovery phrase generated on this device",'
        '"timestamp":${now - 172800000},"read":true}]';
  }

  @override
  Future<String?> readBlockedUsers() async => '["name:spam_account"]';

  @override
  Future<String?> readTheme() async => null;

  @override
  Future<bool> readHapticsEnabled() async => true;

  @override
  Future<String?> readAvatarPath() async => null;

  @override
  Future<String?> readDisplayName() async => 'Ama';

  @override
  Future<bool> isAppLockEnabled() async => true;
}
