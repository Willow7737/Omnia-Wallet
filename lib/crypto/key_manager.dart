import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import '../core/auth_mode.dart';

/// The wallet's identity: either derived from an on-device Ed25519 keypair
/// (self-custody) or linked to a Supabase account (server-assisted).
class WalletIdentity {
  WalletIdentity({
    required this.did,
    this.publicKeyHex,
    this.mode = AuthMode.selfCustody,
  });

  /// Hex-encoded 32-byte Ed25519 public key. Null in Supabase mode — those
  /// accounts have no on-device key.
  final String? publicKeyHex;

  /// `did:omnia:...` — derived from the public key (Mode A) or assigned by
  /// the web signup trigger (Mode B).
  final String did;

  final AuthMode mode;
}

/// Pure key/identity operations — no I/O, no storage. Deterministic and unit
/// testable so we can prove the DID matches the node's derivation.
///
/// Derivation chain:
///   BIP39 mnemonic -> 64-byte seed -> first 32 bytes = Ed25519 seed
///   Ed25519 seed -> keypair
///   DID = "did:omnia:" + sha256(public_key_bytes).hex[..32]
///
/// The DID rule MUST stay identical to `did_from_public_key` in the node's
/// `node/src/api/wallet_auth.rs`.
class KeyManager {
  const KeyManager();

  /// Generate a fresh 12-word BIP39 mnemonic (128 bits of entropy).
  String generateMnemonic() => bip39.generateMnemonic();

  /// Validate a BIP39 mnemonic phrase.
  bool validateMnemonic(String mnemonic) =>
      bip39.validateMnemonic(mnemonic.trim());

  /// Derive the 32-byte Ed25519 seed from a mnemonic.
  Uint8List seedFromMnemonic(String mnemonic) {
    final full = bip39.mnemonicToSeed(mnemonic.trim());
    return Uint8List.fromList(full.sublist(0, 32));
  }

  /// Reconstruct the Ed25519 private key from a 32-byte seed.
  ed.PrivateKey privateKeyFromSeed(Uint8List seed) {
    if (seed.length != 32) {
      throw ArgumentError('Ed25519 seed must be 32 bytes, got ${seed.length}');
    }
    return ed.newKeyFromSeed(seed);
  }

  /// Public key bytes (32) for a private key.
  Uint8List publicKeyBytes(ed.PrivateKey priv) =>
      Uint8List.fromList(ed.public(priv).bytes);

  /// Derive the deterministic DID for a set of public key bytes.
  ///
  /// Must match `did_from_public_key` in the node's `wallet_auth.rs`:
  /// `did:omnia:` + first 32 hex chars of SHA-256(public key).
  String didFromPublicKey(Uint8List publicKey) {
    final digest = crypto.sha256.convert(publicKey);
    final hexDigest = hex.encode(digest.bytes);
    return 'did:omnia:${hexDigest.substring(0, 32)}';
  }

  /// Build the [WalletIdentity] for a 32-byte seed.
  WalletIdentity identityFromSeed(Uint8List seed) {
    final priv = privateKeyFromSeed(seed);
    final pub = publicKeyBytes(priv);
    return WalletIdentity(
      publicKeyHex: hex.encode(pub),
      did: didFromPublicKey(pub),
    );
  }

  /// Sign an arbitrary message with the private key derived from [seed].
  /// Returns the hex-encoded 64-byte Ed25519 signature.
  String signHex(Uint8List seed, String message) {
    final priv = privateKeyFromSeed(seed);
    final sig = ed.sign(priv, Uint8List.fromList(message.codeUnits));
    return hex.encode(sig);
  }
}
