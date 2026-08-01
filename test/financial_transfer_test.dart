import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/config.dart';
import 'package:omnia_wallet/crypto/key_manager.dart';
import 'package:omnia_wallet/data/models.dart';

/// Cross-language agreement tests for the financial transfer authorization.
///
/// The wallet and the node independently implement the same byte encoding.
/// If they ever disagree, every transfer this wallet signs is rejected —
/// silently, and only in production. So the vectors below are not invented
/// here: they were produced by running the node's own
/// `signed_transfer_message` (in `shards/src/financial/ops.rs`) and pasted
/// in verbatim. A change to either implementation breaks these tests.
void main() {
  const km = KeyManager();

  group('financial transfer message encoding (must match the node)', () {
    // Generated from the Rust implementation:
    //   from  = [3u8; 32], to = [5u8; 32], amount = 250, nonce = 7
    const expectedHex =
        '6f6d6e69612d66696e616e6369616c2d7472616e736665723a7631'
        '0303030303030303030303030303030303030303030303030303030303030303'
        '0505050505050505050505050505050505050505050505050505050505050505'
        'fa00000000000000'
        '0700000000000000';

    test('produces byte-identical output to the node', () {
      final msg = km.financialTransferMessage(
        fromPublicKey: Uint8List.fromList(List.filled(32, 3)),
        toPublicKey: Uint8List.fromList(List.filled(32, 5)),
        amount: 250,
        nonce: 7,
      );
      expect(hex.encode(msg), expectedHex);
      // 27-byte domain tag + 32 + 32 + 8 + 8.
      expect(msg.length, 107);
    });

    test('domain tag matches the node constant', () {
      expect(AppConfig.financialTransferPrefix, 'omnia-financial-transfer:v1');
      final msg = km.financialTransferMessage(
        fromPublicKey: Uint8List.fromList(List.filled(32, 3)),
        toPublicKey: Uint8List.fromList(List.filled(32, 5)),
        amount: 250,
        nonce: 7,
      );
      expect(
        String.fromCharCodes(msg.sublist(0, 27)),
        'omnia-financial-transfer:v1',
      );
    });

    test('is distinct from the UBC spend authorization', () {
      // A UBC spend must never be replayable as a financial transfer.
      // Different domain tags are what guarantee that.
      expect(
        AppConfig.financialTransferPrefix,
        isNot(AppConfig.transferMessagePrefix),
      );
    });

    test('amounts and nonces are little-endian u64', () {
      final msg = km.financialTransferMessage(
        fromPublicKey: Uint8List.fromList(List.filled(32, 0)),
        toPublicKey: Uint8List.fromList(List.filled(32, 0)),
        amount: 1,
        nonce: 258, // 0x0102 -> 02 01 00 ...
      );
      expect(hex.encode(msg.sublist(91, 99)), '0100000000000000');
      expect(hex.encode(msg.sublist(99, 107)), '0201000000000000');
    });

    test('every signed field changes the message', () {
      Uint8List build({int amount = 250, int nonce = 7, int toByte = 5}) =>
          km.financialTransferMessage(
            fromPublicKey: Uint8List.fromList(List.filled(32, 3)),
            toPublicKey: Uint8List.fromList(List.filled(32, toByte)),
            amount: amount,
            nonce: nonce,
          );

      final base = hex.encode(build());
      expect(hex.encode(build(amount: 251)), isNot(base));
      expect(hex.encode(build(nonce: 8)), isNot(base));
      expect(hex.encode(build(toByte: 6)), isNot(base));
    });

    test('rejects malformed keys and negative values', () {
      expect(
        () => km.financialTransferMessage(
          fromPublicKey: Uint8List(31),
          toPublicKey: Uint8List(32),
          amount: 1,
          nonce: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => km.financialTransferMessage(
          fromPublicKey: Uint8List(32),
          toPublicKey: Uint8List(31),
          amount: 1,
          nonce: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => km.financialTransferMessage(
          fromPublicKey: Uint8List(32),
          toPublicKey: Uint8List(32),
          amount: -1,
          nonce: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('financial transfer signature (must verify on the node)', () {
    test('signing a transfer reproduces the node-generated signature', () {
      // Seed [3u8; 32] -> the public key and signature below were produced
      // by ed25519-dalek in the node's test harness over the canonical
      // message for (that pubkey, to=[5u8; 32], amount=250, nonce=7).
      final seed = Uint8List.fromList(List.filled(32, 3));
      final identity = km.identityFromSeed(seed);

      expect(
        identity.publicKeyHex,
        'ed4928c628d1c2c6eae90338905995612959273a5c63f93636c14614ac8737d1',
        reason: 'wallet key derivation must match the node',
      );

      final msg = km.financialTransferMessage(
        fromPublicKey: Uint8List.fromList(hex.decode(identity.publicKeyHex!)),
        toPublicKey: Uint8List.fromList(List.filled(32, 5)),
        amount: 250,
        nonce: 7,
      );

      expect(
        km.signBytesHex(seed, msg),
        '52fa8d6cb50440b776dbf6d65a6ed1fb589ae07505804248e437f814290812b8'
        '6b8f9203c047c004e291dd27a5669a863ed4e51e6399bf03a5e8c79efd76cd05',
        reason: 'a signature the node will not accept is worse than no transfer',
      );
    });
  });

  group('financial models', () {
    test('parses a balance response', () {
      final b = FinancialBalance.fromJson(<String, dynamic>{
        'public_key': 'aa' * 32,
        'did': 'did:omnia:deadbeef',
        'balance': 750,
        'next_nonce': 3,
        'total_supply': 1000,
      });
      expect(b.balance, 750);
      expect(b.nextNonce, 3);
      expect(b.totalSupply, 1000);
    });

    test('a never-seen account starts at nonce 1, not 0', () {
      // The node requires nonce > last accepted and treats a fresh account
      // as having none, so the first usable nonce is 1. Defaulting to 0
      // here would make every first transfer fail.
      final b = FinancialBalance.fromJson(const {});
      expect(b.nextNonce, 1);
      expect(FinancialBalance.empty('aa', 'did:omnia:x').nextNonce, 1);
    });

    test('parses a transfer result including the recipient balance', () {
      final r = FinancialTransferResult.fromJson(const {
        'status': 'applied',
        'amount': 250,
        'sender_balance': 750,
        'recipient_balance': 250,
        'event_id': 'abc123',
      });
      expect(r.status, 'applied');
      // The field that distinguishes a transfer from a UBC burn.
      expect(r.recipientBalance, 250);
      expect(r.senderBalance, 750);
      expect(r.eventId, 'abc123');
    });
  });
}
