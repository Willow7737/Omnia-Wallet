import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/models.dart';
import 'package:omnia_wallet/data/wallet_repository.dart';
import 'package:omnia_wallet/state/notices.dart';
import 'package:omnia_wallet/state/providers.dart';

/// The node makes no ordering guarantee for the transfer log, and both screens
/// used to guess at it with `.reversed` — which put the newest transfers at the
/// bottom of Activity and kept them out of Home's "recent" list altogether.
/// The order is now established once, in the provider.
void main() {
  TransferRecord at(String id, Duration ago) => TransferRecord(
        id: id,
        fromDid: 'did:omnia:aaaa',
        toDid: 'did:omnia:bbbb',
        amount: 10,
        newBalance: 100,
        status: 'completed',
        timestamp: DateTime.now().subtract(ago).millisecondsSinceEpoch,
      );

  Future<List<TransferRecord>> orderOf(List<TransferRecord> fromNode) async {
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(_StubWallet(fromNode)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(historyProvider.future);
  }

  group('historyProvider', () {
    test('returns newest first when the node returns oldest first', () async {
      final ordered = await orderOf([
        at('oldest', const Duration(days: 3)),
        at('middle', const Duration(days: 1)),
        at('newest', const Duration(minutes: 1)),
      ]);
      expect(ordered.map((r) => r.id), ['newest', 'middle', 'oldest']);
    });

    test('returns newest first when the node returns them shuffled', () async {
      final ordered = await orderOf([
        at('middle', const Duration(days: 1)),
        at('oldest', const Duration(days: 3)),
        at('newest', const Duration(minutes: 1)),
      ]);
      expect(ordered.map((r) => r.id), ['newest', 'middle', 'oldest']);
    });

    test('leaves the order the node gave us untouched', () async {
      // Sorting a fixed-length list in place would corrupt the repository's
      // own list; the provider must copy before sorting.
      final fromNode = [
        at('oldest', const Duration(days: 3)),
        at('newest', const Duration(minutes: 1)),
      ];
      await orderOf(fromNode);
      expect(fromNode.map((r) => r.id), ['oldest', 'newest']);
    });

    test('handles an empty log', () async {
      expect(await orderOf([]), isEmpty);
    });
  });

  group('AppNotice.destination', () {
    // Every notification has to open something — that was the whole complaint.
    test('every type routes somewhere', () {
      for (final type in NoticeType.values) {
        final notice = AppNotice(
          id: '1',
          type: type,
          title: 't',
          body: 'b',
          timestamp: 0,
        );
        expect(notice.destination, startsWith('/'),
            reason: '${type.name} has no destination');
        expect(notice.destination, isNotEmpty);
      }
    });

    test('a sent notice opens the activity log', () {
      const notice = AppNotice(
        id: '1',
        type: NoticeType.sent,
        title: 'Sent 39 UBC',
        body: '',
        timestamp: 0,
      );
      expect(notice.destination, '/activity');
    });

    test('survives a JSON round-trip', () {
      const original = AppNotice(
        id: '1',
        type: NoticeType.vote,
        title: 'Vote recorded',
        body: 'for',
        timestamp: 42,
        read: true,
      );
      final restored = AppNotice.fromJson(original.toJson());
      expect(restored.type, original.type);
      expect(restored.read, isTrue);
      expect(restored.destination, original.destination);
    });
  });
}

/// A wallet repository that hands back a fixed log. Only `history` is
/// exercised here; the rest would need a live node.
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

  @override
  Future<OmniaQuote> requestOmniaQuote({
    required int ghsAmountPesewas,
    required String provider,
    required String customerNumber,
  }) =>
      throw UnimplementedError();

  @override
  Future<BuyOmniaResult> buyOmnia({
    required String quoteId,
    required String customerNumber,
  }) =>
      throw UnimplementedError();

  @override
  Future<PaymentOrderStatus> getPaymentOrderStatus({
    required String orderId,
  }) =>
      throw UnimplementedError();

  @override
  Future<MerchantPaymentRequest> createMerchantPaymentRequest({
    required String merchantId,
    required int ghsPricePesewas,
  }) =>
      throw UnimplementedError();

  @override
  Future<MerchantReceipt> getMerchantReceipt({
    required String merchantId,
    required String paymentId,
  }) =>
      throw UnimplementedError();
}
