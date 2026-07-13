import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/config.dart';
import 'package:omnia_wallet/crypto/key_manager.dart';

void main() {
  const km = KeyManager();

  group('SHA-256 (must match the node)', () {
    test('empty input matches the canonical SHA-256 test vector', () {
      // If this fails, the wallet's DID will not match the node's, so every
      // balance/transfer lookup would break. Pin the implementation here.
      final digest = hex.encode(crypto.sha256.convert(Uint8List(0)).bytes);
      expect(
        digest,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('"abc" matches the canonical SHA-256 test vector', () {
      final digest = hex.encode(
          crypto.sha256.convert(Uint8List.fromList('abc'.codeUnits)).bytes);
      expect(
        digest,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('DID derivation', () {
    test('matches the node rule: did:omnia: + sha256(pubkey)[..32]', () {
      final pubkey = Uint8List.fromList(List<int>.filled(32, 7));
      final expectedHash = hex.encode(crypto.sha256.convert(pubkey).bytes);
      final did = km.didFromPublicKey(pubkey);
      expect(did, 'did:omnia:${expectedHash.substring(0, 32)}');
      expect(did.length, 'did:omnia:'.length + 32);
      // Shared cross-repo vector — the identical literal is asserted in the
      // node's wallet_auth.rs (did_derivation_matches_shared_cross_repo_vector).
      expect(did, 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237');
    });

    test('is deterministic and differs per key', () {
      final a = km.didFromPublicKey(Uint8List.fromList(List.filled(32, 1)));
      final b = km.didFromPublicKey(Uint8List.fromList(List.filled(32, 1)));
      final c = km.didFromPublicKey(Uint8List.fromList(List.filled(32, 2)));
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('key derivation', () {
    test('seed from a known mnemonic is deterministic and 32 bytes', () {
      const mnemonic =
          'legal winner thank year wave sausage worth useful legal winner thank yellow';
      final seed1 = km.seedFromMnemonic(mnemonic);
      final seed2 = km.seedFromMnemonic(mnemonic);
      expect(seed1.length, 32);
      expect(hex.encode(seed1), hex.encode(seed2));
    });

    test('identity is stable for a given seed', () {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final id1 = km.identityFromSeed(seed);
      final id2 = km.identityFromSeed(seed);
      expect(id1.publicKeyHex, id2.publicKeyHex);
      expect(id1.did, id2.did);
      expect(id1.publicKeyHex!.length, 64); // 32 bytes hex
    });

    test('signature over the challenge message verifies', () {
      final seed = Uint8List.fromList(List.generate(32, (i) => (i * 3) % 256));
      final priv = km.privateKeyFromSeed(seed);
      final pub = ed.public(priv);

      const nonce = 'deadbeefcafe';
      final message = '${AppConfig.authMessagePrefix}$nonce';
      final sigHex = km.signHex(seed, message);

      final ok = ed.verify(
        pub,
        Uint8List.fromList(message.codeUnits),
        Uint8List.fromList(hex.decode(sigHex)),
      );
      expect(ok, isTrue);

      // Tampered message must fail.
      final bad = ed.verify(
        pub,
        Uint8List.fromList('${AppConfig.authMessagePrefix}00'.codeUnits),
        Uint8List.fromList(hex.decode(sigHex)),
      );
      expect(bad, isFalse);
    });

    test('mnemonic validation rejects garbage', () {
      expect(
          km.validateMnemonic('not a real phrase at all nope nope'), isFalse);
      expect(km.validateMnemonic(km.generateMnemonic()), isTrue);
    });
  });

  group('transfer authorization (Step 2, self-sovereign spend)', () {
    test('canonical message matches the node field order and delimiters', () {
      final msg = km.transferMessage(
        nonce: '00ff',
        fromDid: 'did:omnia:from',
        toDid: 'did:omnia:to',
        amount: 500,
      );
      // MUST match transfer_message in the node's wallet_auth.rs.
      expect(msg, 'omnia-transfer-v1\n00ff\ndid:omnia:from\ndid:omnia:to\n500');
    });

    test('signature over the transfer message verifies; tampering fails', () {
      final seed = Uint8List.fromList(List.generate(32, (i) => (i * 5) % 256));
      final priv = km.privateKeyFromSeed(seed);
      final pub = ed.public(priv);
      final fromDid = km.didFromPublicKey(km.publicKeyBytes(priv));

      final message = km.transferMessage(
        nonce: 'cafe',
        fromDid: fromDid,
        toDid: 'did:omnia:recipient',
        amount: 42,
      );
      final sigHex = km.signHex(seed, message);

      expect(
        ed.verify(pub, Uint8List.fromList(message.codeUnits),
            Uint8List.fromList(hex.decode(sigHex))),
        isTrue,
      );

      // Any mutated field invalidates the signature.
      for (final tampered in [
        km.transferMessage(
            nonce: 'cafe',
            fromDid: fromDid,
            toDid: 'did:omnia:recipient',
            amount: 43),
        km.transferMessage(
            nonce: 'cafe',
            fromDid: fromDid,
            toDid: 'did:omnia:evil',
            amount: 42),
        km.transferMessage(
            nonce: 'beef',
            fromDid: fromDid,
            toDid: 'did:omnia:recipient',
            amount: 42),
      ]) {
        expect(
          ed.verify(pub, Uint8List.fromList(tampered.codeUnits),
              Uint8List.fromList(hex.decode(sigHex))),
          isFalse,
        );
      }
    });
  });
}
