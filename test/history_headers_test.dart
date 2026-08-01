import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/core/format.dart';
import 'package:omnia_wallet/crypto/key_manager.dart';
import 'package:omnia_wallet/data/models.dart';
import 'package:omnia_wallet/data/wallet_repository.dart';
import 'package:omnia_wallet/features/history/history_screen.dart';
import 'package:omnia_wallet/state/providers.dart';

/// A pinned day header is supposed to be *displaced* by the next day's header
/// as it arrives, not to park itself at the top of the screen for the rest of
/// the list. The difference between the two is invisible to `analyze` and to a
/// render smoke test — both spellings lay out and paint fine — so it is
/// measured.
void main() {
  const did = 'did:omnia:aaaa';

  TransferRecord at(String id, Duration ago) => TransferRecord(
        id: id,
        fromDid: did,
        toDid: 'did:omnia:bbbb',
        amount: 10,
        newBalance: 100,
        status: 'completed',
        timestamp: DateTime.now().subtract(ago).millisecondsSinceEpoch,
      );

  /// Two long day runs, so the first day's header has plenty of list to try
  /// to stick over before the second day's header reaches it.
  List<TransferRecord> twoDays() => [
        for (var i = 0; i < 12; i++) at('today-$i', Duration(minutes: 5 + i)),
        for (var i = 0; i < 12; i++)
          at('older-$i', Duration(days: 3, minutes: i)),
      ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_StubWallet(twoDays())),
          identityProvider.overrideWith((ref) async => WalletIdentity(
                did: did,
                publicKeyHex: 'ab',
              )),
        ],
        child: MaterialApp(
          theme: OmniaTheme.light(),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Both days' headers, as they are rendered.
  final firstDay = Fmt.dayLabel(DateTime.now()).toUpperCase();
  final secondDay =
      Fmt.dayLabel(DateTime.now().subtract(const Duration(days: 3)))
          .toUpperCase();

  testWidgets('the newer date is replaced by the next one, not kept above it',
      (tester) async {
    await pump(tester);
    expect(find.text(firstDay), findsOneWidget, reason: 'no day header');
    expect(firstDay, isNot(secondDay), reason: 'the fixture needs two days');

    // Scroll clear of the first day entirely.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pump();

    // This is the reported bug, stated as a measurement: with a bare pinned
    // header, "today" stays stuck to the top of the screen for the whole rest
    // of the log, and every later date piles up underneath it. Grouped, it is
    // pushed out by the date that follows it.
    expect(
      find.text(firstDay),
      findsNothing,
      reason: '$firstDay is still pinned after its own transactions ended',
    );
    expect(find.text(secondDay), findsOneWidget);

    final header = tester.getRect(find.text(secondDay));
    final list = tester.getRect(find.byType(CustomScrollView));
    // And the surviving header is the one actually pinned at the top, rather
    // than sitting below the leftovers of the previous one.
    expect(header.top - list.top, lessThan(40));
  });

  testWidgets('only one date is pinned at a time', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();

    final list = tester.getRect(find.byType(CustomScrollView));
    final pinned = [
      for (final label in [firstDay, secondDay])
        if (find.text(label).evaluate().isNotEmpty)
          if (tester.getRect(find.text(label)).top - list.top < 60) label,
    ];
    expect(pinned, hasLength(lessThanOrEqualTo(1)),
        reason: 'dates are stacking at the top instead of replacing');
  });

  testWidgets('renders with a single day without throwing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _StubWallet([at('a', const Duration(minutes: 1))]),
          ),
          identityProvider.overrideWith((ref) async => WalletIdentity(
                did: did,
                publicKeyHex: 'ab',
              )),
        ],
        child: MaterialApp(
          theme: OmniaTheme.light(),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}

class _StubWallet implements WalletRepository {
  _StubWallet(this.log);

  final List<TransferRecord> log;

  @override
  Future<List<TransferRecord>> history({int limit = 50}) async => log;

  @override
  Future<Balance> balance() => throw UnimplementedError();

  @override
  Future<TransferResult> send({
    required String toDid,
    required int amount,
  }) =>
      throw UnimplementedError();

  @override
  Future<FinancialBalance> financialBalance() => throw UnimplementedError();

  @override
  Future<FinancialTransferResult> sendFinancial({
    required String toPublicKeyHex,
    required int amount,
  }) =>
      throw UnimplementedError();
}
