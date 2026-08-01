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

  group('payment address (pk)', () {
    const pk =
        'ed4928c628d1c2c6eae90338905995612959273a5c63f93636c14614ac8737d1';

    test('round-trips a payable request', () {
      const req = PaymentRequest(did: did, amount: 42, publicKeyHex: pk);
      final uri = req.toUri();
      expect(uri, 'omnia:$did?amount=42&pk=$pk');

      final parsed = PaymentRequest.parse(uri)!;
      expect(parsed.did, did);
      expect(parsed.amount, 42);
      expect(parsed.publicKeyHex, pk);
      expect(parsed.isPayable, isTrue);
    });

    test('carries the key without an amount', () {
      const req = PaymentRequest(did: did, publicKeyHex: pk);
      expect(req.toUri(), 'omnia:$did?pk=$pk');
      expect(PaymentRequest.parse(req.toUri())!.publicKeyHex, pk);
    });

    test('a DID-only request is not payable', () {
      // The whole point of the field: a DID is a one-way hash of the key,
      // so transferable value can never reach a code that lacks the key.
      final parsed = PaymentRequest.parse('omnia:$did?amount=5')!;
      expect(parsed.publicKeyHex, isNull);
      expect(parsed.isPayable, isFalse);
    });

    test('older DID-only codes still round-trip unchanged', () {
      const req = PaymentRequest(did: did, amount: 9);
      expect(req.toUri(), 'omnia:$did?amount=9');
      expect(PaymentRequest.parse(req.toUri())!.isPayable, isFalse);
    });

    test('drops a malformed key rather than carrying it forward', () {
      // A corrupted QR should degrade to a DID-only request, not produce an
      // address that silently fails to be credited.
      expect(PaymentRequest.parse('omnia:$did?pk=abcd')!.publicKeyHex, isNull);
      expect(
        PaymentRequest.parse('omnia:$did?pk=${'z' * 64}')!.publicKeyHex,
        isNull,
      );
      // 65 hex chars is not a key either.
      expect(
        PaymentRequest.parse('omnia:$did?pk=${'a' * 65}')!.publicKeyHex,
        isNull,
      );
    });

    test('normalises the key to lower case', () {
      final parsed = PaymentRequest.parse('omnia:$did?pk=${pk.toUpperCase()}')!;
      expect(parsed.publicKeyHex, pk);
    });
  });
}
