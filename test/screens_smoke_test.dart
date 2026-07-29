import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/crypto/key_manager.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/governance.dart';
import 'package:omnia_wallet/data/models.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/about/about_screen.dart';
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
import 'package:omnia_wallet/features/splash/splash_screen.dart';
import 'package:omnia_wallet/state/governance.dart';
import 'package:omnia_wallet/state/news.dart';
import 'package:omnia_wallet/state/providers.dart';

/// Renders every redesigned screen against real data and asserts nothing
/// throws.
///
/// `flutter analyze` cannot see layout failures — an `Expanded` under an
/// unbounded parent, an `IntrinsicWidth` around an infinite child, a missing
/// theme extension — because they are runtime assertions inside `performLayout`.
/// A screen that compiles perfectly can still red-screen on first paint, so
/// each screen gets pumped here in both the light and dark themes.
void main() {
  const did = 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237';
  const otherDid = 'did:omnia:71a9c0e0';

  final identity = WalletIdentity(
    did: did,
    publicKeyHex: 'ab' * 32,
  );

  final balance = Balance(
    did: did,
    balance: 800,
    monthlyQuota: 1000,
    currentEpoch: 0,
    isRegistered: true,
  );

  List<TransferRecord> history() => [
        TransferRecord(
          id: 'tx-1',
          fromDid: did,
          toDid: otherDid,
          amount: 39,
          newBalance: 761,
          status: 'completed',
          timestamp: DateTime.now()
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          lane0Final: true,
          // `isWalletSigned` is derived from this, and drives the extra
          // provenance badge on the tile and the detail screen.
          provenance: 'wallet_signed',
        ),
        TransferRecord(
          id: 'tx-2',
          fromDid: otherDid,
          toDid: did,
          amount: 97,
          newBalance: 0,
          status: 'completed',
          // Two days back, so the day-grouping headers get exercised too.
          timestamp: DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
        ),
      ];

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
      title: 'Lane 0 finality is live',
      body: 'Transfers now settle on the fast path. ' * 6,
      tags: const ['protocol', 'release'],
      author: 'omnia',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      replyCount: 3,
    ),
  ];

  final proposals = [
    Proposal(
      id: 'prop-1',
      description: 'Raise the monthly quota to 1,200 UBC',
      createdAtEpoch: 0,
      expiresAtEpoch: 4,
      votesFor: 12,
      votesAgainst: 4,
      votesAbstain: 1,
      executionTime: null,
      status: 'voting',
      totalParticipation: 17,
    ),
    // A zero-vote proposal exercises the tally bar's empty branch.
    Proposal(
      id: 'prop-2',
      description: 'Adopt a shorter epoch',
      createdAtEpoch: 0,
      expiresAtEpoch: 2,
      votesFor: 0,
      votesAgainst: 0,
      votesAbstain: 0,
      executionTime: null,
      status: 'passed',
      totalParticipation: 0,
    ),
  ];

  /// Every async provider a screen might read, resolved to real-looking data.
  List<Override> overrides() => [
        secureStoreProvider.overrideWithValue(_FakeStore()),
        identityProvider.overrideWith((ref) async => identity),
        hasWalletProvider.overrideWith((ref) async => true),
        balanceProvider.overrideWith((ref) async => balance),
        historyProvider.overrideWith((ref) async => history()),
        nodeInfoProvider.overrideWith((ref) async => nodeInfo),
        displayNameProvider.overrideWith((ref) async => 'Ama'),
        newsPostsProvider.overrideWith((ref) async => posts),
        proposalsProvider.overrideWith((ref) async => proposals),
      ];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(theme: theme, home: screen),
      ),
    );
    // One frame to build, one to let the async providers resolve, then long
    // enough to drain every entrance animation *and* the slowest scheduled
    // timer on any screen (Notifications marks itself read after 1.2s).
    // `pumpAndSettle` would hang on the shimmer and splash controllers, which
    // repeat forever by design.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
  }

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Activity': const HistoryScreen(),
    'News': const NewsScreen(),
    'Notifications': const NotificationsScreen(),
    'Profile': const ProfileScreen(),
    'Send': const SendScreen(),
    'Receive': const ReceiveScreen(),
    'Settings': const SettingsScreen(),
    'Contacts': const ContactsScreen(),
    'Governance': const GovernanceScreen(),
    'Network': const NetworkScreen(),
    'Safety': const SafetyScreen(),
    'About': const AboutScreen(),
    'Splash': const SplashScreen(),
    'Transaction': TransactionScreen(record: history().first),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders in the light theme', (tester) async {
      await pump(tester, entry.value, theme: OmniaTheme.light());
    });

    testWidgets('${entry.key} renders in the dark theme', (tester) async {
      await pump(tester, entry.value, theme: OmniaTheme.dark());
    });
  }

  // The tightest realistic case: a small phone at the maximum text scale the
  // app allows (`main.dart` clamps to 1.3x). This is where a fixed-width row or
  // an un-ellipsised label overflows.
  for (final entry in screens.entries) {
    testWidgets('${entry.key} survives a narrow, large-text viewport',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: OmniaTheme.dim(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: entry.value,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
    });
  }

  group('theme', () {
    test('all three themes carry the OmniaColors extension', () {
      for (final name in OmniaThemeName.values) {
        final theme = OmniaTheme.of(name);
        expect(
          theme.extension<OmniaColors>(),
          isNotNull,
          reason: '${name.label} is missing its palette extension',
        );
      }
    });

    test('dark themes invert the contrast ramp end to end', () {
      // ALF's `invertPalette` is what keeps light and dark in lockstep; if the
      // ramp stopped mirroring, dark mode would silently lose contrast.
      final light = OmniaPalette.defaults;
      final dark = light.invert();
      expect(dark.contrast0, light.contrast1000);
      expect(dark.contrast1000, light.contrast0);
      expect(dark.contrast100, light.contrast900);
      // 500 is the fixed midpoint of each semantic ramp.
      expect(dark.primary500, light.primary500);
    });

    test('an untouched wallet follows the device', () {
      // The reported fault: the app ignored the phone's light/dark setting
      // entirely. The cause was here — a null preference (which is every
      // wallet that has never opened Settings) answered Dim, a fixed theme,
      // instead of deferring.
      expect(OmniaThemeChoiceX.fromWire(null), OmniaThemeChoice.system);
      expect(OmniaThemeChoiceX.fromWire(''), OmniaThemeChoice.system);
      expect(OmniaThemeChoiceX.fromWire('nonsense'), OmniaThemeChoice.system);
    });

    test('System resolves against the device, the rest ignore it', () {
      expect(
        OmniaThemeChoice.system.resolve(Brightness.light),
        OmniaThemeName.light,
      );
      expect(
        OmniaThemeChoice.system.resolve(Brightness.dark),
        OmniaThemeName.dim,
        reason: 'system dark should land on the default dark, not true black',
      );

      // An explicit choice is an instruction, not a preference: the device
      // being set the other way must not override it.
      for (final brightness in Brightness.values) {
        expect(
          OmniaThemeChoice.light.resolve(brightness),
          OmniaThemeName.light,
        );
        expect(OmniaThemeChoice.dim.resolve(brightness), OmniaThemeName.dim);
        expect(OmniaThemeChoice.dark.resolve(brightness), OmniaThemeName.dark);
      }
    });

    test('every choice survives a round trip through storage', () {
      for (final choice in OmniaThemeChoice.values) {
        expect(OmniaThemeChoiceX.fromWire(choice.wire), choice);
      }
    });

    testWidgets('a System wallet repaints when the device flips',
        (tester) async {
      // The end of the chain, not the enum: it is MaterialApp that resolves
      // ThemeMode against the platform, so this is the only assertion that
      // actually says the app follows the phone.
      Widget app(OmniaThemeChoice choice, Brightness platform) {
        final themes = OmniaTheme.modeFor(choice);
        return MediaQuery(
          data: MediaQueryData(platformBrightness: platform),
          child: MaterialApp(
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: themes.mode,
            home: Builder(
              builder: (context) => Text(
                context.omnia.isDark ? 'dark' : 'light',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(app(OmniaThemeChoice.system, Brightness.light));
      expect(find.text('light'), findsOneWidget);

      await tester.pumpWidget(app(OmniaThemeChoice.system, Brightness.dark));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('dark'), findsOneWidget,
          reason: 'the device went dark and the app stayed light');

      // And an explicit choice holds against the device.
      await tester.pumpWidget(app(OmniaThemeChoice.light, Brightness.dark));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('light'), findsOneWidget,
          reason: 'an explicit Light was overridden by the device');
    });

    test('page background and body text always differ', () {
      for (final name in OmniaThemeName.values) {
        final o = OmniaTheme.of(name).extension<OmniaColors>()!;
        expect(o.bg, isNot(o.text), reason: '${name.label} is unreadable');
      }
    });
  });

  group('layout regressions', () {
    testWidgets('the governance tally bar has height', (tester) async {
      // A childless ColoredBox sizes to `constraints.smallest`, so under a
      // centre-aligned Row every segment silently collapsed to zero and the
      // bar disappeared. Nothing throws when that happens — only a render-box
      // measurement catches it.
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: OmniaTheme.light(),
            home: const GovernanceScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final segments = find.descendant(
        of: find.byType(GovernanceScreen),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsWidgets, reason: 'tally bar drew no segments');

      for (var i = 0; i < tester.widgetList(segments).length; i++) {
        final size = tester.getSize(segments.at(i));
        expect(size.height, greaterThan(0),
            reason: 'tally segment $i collapsed to zero height');
        expect(size.width, greaterThan(0),
            reason: 'tally segment $i collapsed to zero width');
      }
    });
  });
}

/// Secure storage is a platform channel, which does not exist under
/// `flutter test`. Every read resolves to "nothing stored yet".
class _FakeStore extends SecureStore {
  @override
  Future<String?> readContacts() async => null;

  @override
  Future<String?> readNotices() async => null;

  @override
  Future<String?> readBlockedUsers() async => null;

  @override
  Future<String?> readTheme() async => null;

  @override
  Future<bool> readHapticsEnabled() async => true;

  @override
  Future<String?> readAvatarPath() async => null;

  @override
  Future<String?> readDisplayName() async => 'Ama';

  @override
  Future<bool> isAppLockEnabled() async => false;
}
