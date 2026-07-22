import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/payment_request.dart';

void main() {
  const did = 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237';

  group('PaymentRequest.toUri', () {
    test('DID-only omits the amount component', () {
      expect(const PaymentRequest(did: did).toUri(), 'omnia:$did');
    });

    test('encodes a positive amount', () {
      expect(
        const PaymentRequest(did: did, amount: 500).toUri(),
        'omnia:$did?amount=500',
      );
    });
  });

  group('PaymentRequest.parse', () {
    test('round-trips an amount request', () {
      final uri = const PaymentRequest(did: did, amount: 500).toUri();
      final parsed = PaymentRequest.parse(uri)!;
      expect(parsed.did, did);
      expect(parsed.amount, 500);
    });

    test('accepts a bare DID with no amount', () {
      final parsed = PaymentRequest.parse(did)!;
      expect(parsed.did, did);
      expect(parsed.amount, isNull);
    });

    test('lower-cases the DID hex to match the node derivation', () {
      final parsed = PaymentRequest.parse(
        'omnia:DID:OMNIA:4BB06F8E4E3A7715D201D573D0AA4237?amount=12',
      )!;
      expect(parsed.did, did);
      expect(parsed.amount, 12);
    });

    test('drops a non-positive or non-numeric amount (DID-only)', () {
      expect(PaymentRequest.parse('omnia:$did?amount=0')!.amount, isNull);
      expect(PaymentRequest.parse('omnia:$did?amount=-5')!.amount, isNull);
      expect(PaymentRequest.parse('omnia:$did?amount=lots')!.amount, isNull);
      // The DID still parses in every case.
      expect(PaymentRequest.parse('omnia:$did?amount=0')!.did, did);
    });

    test('tolerates surrounding whitespace', () {
      final parsed = PaymentRequest.parse('  omnia:$did?amount=7 \n')!;
      expect(parsed.did, did);
      expect(parsed.amount, 7);
    });

    test('rejects payloads without a well-formed Omnia DID', () {
      expect(PaymentRequest.parse(null), isNull);
      expect(PaymentRequest.parse(''), isNull);
      expect(PaymentRequest.parse('https://example.com'), isNull);
      expect(PaymentRequest.parse('did:omnia:dead'), isNull); // too short
    });
  });
}
