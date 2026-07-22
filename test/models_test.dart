import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/api_client.dart';
import 'package:omnia_wallet/data/models.dart';

void main() {
  test('Balance parses the node schema', () {
    final b = Balance.fromJson({
      'did': 'did:omnia:abc',
      'balance': 950,
      'monthly_quota': 1000,
      'current_epoch': 3,
      'is_registered': true,
    });
    expect(b.did, 'did:omnia:abc');
    expect(b.balance, 950);
    expect(b.monthlyQuota, 1000);
    expect(b.currentEpoch, 3);
    expect(b.isRegistered, isTrue);
  });

  test('TransferRecord parses and exposes a DateTime', () {
    final r = TransferRecord.fromJson({
      'id': 'abc',
      'from_did': 'did:omnia:from',
      'to_did': 'did:omnia:to',
      'amount': 500,
      'timestamp': 1700000000000,
      'status': 'completed',
      'new_balance': 500,
    });
    expect(r.amount, 500);
    expect(r.toDid, 'did:omnia:to');
    expect(r.dateTime.millisecondsSinceEpoch, 1700000000000);
    // Fields absent on older nodes fall back to safe defaults.
    expect(r.eventId, isNull);
    expect(r.provenance, 'node_attested');
    expect(r.isWalletSigned, isFalse);
    expect(r.lane0Final, isNull);
  });

  test('TransferRecord parses on-chain event, provenance, and finality', () {
    final r = TransferRecord.fromJson({
      'id': 'abc',
      'from_did': 'did:omnia:from',
      'to_did': 'did:omnia:to',
      'amount': 500,
      'timestamp': 1700000000000,
      'status': 'completed',
      'new_balance': 9500,
      'event_id': 'deadbeef',
      'provenance': 'wallet_signed',
      'lane0_final': true,
    });
    expect(r.eventId, 'deadbeef');
    expect(r.provenance, 'wallet_signed');
    expect(r.isWalletSigned, isTrue);
    expect(r.lane0Final, isTrue);
  });

  test('TransferResult parses provenance; defaults to node_attested', () {
    final signed = TransferResult.fromJson({
      'status': 'completed',
      'amount': 500,
      'new_balance': 9500,
      'provenance': 'wallet_signed',
    });
    expect(signed.provenance, 'wallet_signed');
    expect(signed.isWalletSigned, isTrue);

    // Older nodes / node-attested transfers omit the field.
    final legacy = TransferResult.fromJson({
      'status': 'completed',
      'amount': 500,
      'new_balance': 9500,
    });
    expect(legacy.provenance, 'node_attested');
    expect(legacy.isWalletSigned, isFalse);
  });

  test('TransferAuthorization serializes to the node wire shape', () {
    final auth = TransferAuthorization(
      publicKeyHex: 'aa',
      nonce: 'bb',
      signatureHex: 'cc',
    );
    expect(auth.toJson(), {
      'public_key': 'aa',
      'nonce': 'bb',
      'signature': 'cc',
    });
  });

  test('TransferResult parses provenance; defaults to node_attested', () {
    final signed = TransferResult.fromJson({
      'status': 'completed',
      'amount': 500,
      'new_balance': 9500,
      'provenance': 'wallet_signed',
    });
    expect(signed.provenance, 'wallet_signed');
    expect(signed.isWalletSigned, isTrue);

    // Older nodes / node-attested transfers omit the field.
    final legacy = TransferResult.fromJson({
      'status': 'completed',
      'amount': 500,
      'new_balance': 9500,
    });
    expect(legacy.provenance, 'node_attested');
    expect(legacy.isWalletSigned, isFalse);
  });

  test('TransferAuthorization serializes to the node wire shape', () {
    final auth = TransferAuthorization(
      publicKeyHex: 'aa',
      nonce: 'bb',
      signatureHex: 'cc',
    );
    expect(auth.toJson(), {
      'public_key': 'aa',
      'nonce': 'bb',
      'signature': 'cc',
    });
  });

  test('LoginResponse and ChallengeResponse parse', () {
    final c = ChallengeResponse.fromJson({
      'did': 'did:omnia:x',
      'nonce': 'ff00',
      'expires_at': 123,
      'message': 'omnia-auth:ff00',
    });
    expect(c.nonce, 'ff00');
    expect(c.message, 'omnia-auth:ff00');

    final l = LoginResponse.fromJson({
      'did': 'did:omnia:x',
      'token': 'jwt.abc.def',
      'expires_in': 86400,
    });
    expect(l.token, 'jwt.abc.def');
    expect(l.expiresIn, 86400);
  });

  test('Session expiry accounts for skew', () {
    final soon = Session(
      did: 'd',
      token: 't',
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    expect(soon.isExpiredWithin(const Duration(seconds: 60)), isTrue);
    expect(soon.isExpiredWithin(const Duration(seconds: 5)), isFalse);
  });
}
